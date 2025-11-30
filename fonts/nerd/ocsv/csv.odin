package ocsv

import "core:fmt"
import "core:encoding/csv"
import "core:log"
import "core:os"
import "core:time"
import "core:reflect"
import "core:slice"
import "core:strconv"
import "core:strings"
import "base:runtime"

Err :: enum i32 {
    None = 0,
    MissingTag = 1,
    Allocation_Error = 2,
    Bad_Parameter = 3,
    Parsing_Failed = 4,
    Unsupported_Type = 5,
    Invalid_CSV_Format = 6,
    No_Content = 7,
    Field_Not_Found = 8,
    Time_Format_Error = 9,
    File_Error = 10,
}

// read_file reads a CSV file from the given path and returns its content as a 2D slice of strings.
// It now returns a dynamic array that the caller is responsible for deleting.
read_file :: proc(path: string) -> (data: [][]string, err: Err) {
    file, os_err := os.open(path, os.O_RDONLY, 0o666)
    if os_err != os.ERROR_NONE {
        log.errorf("Error opening CSV file '%s': %v", path, os_err)
        return nil, .File_Error
    }
    defer os.close(file) // Ensure the file is closed

    stream := os.stream_from_handle(file)
    reader: csv.Reader
    // IMPORTANT: we use context.allocator for the CSV reader internal buffer.
    // to avoid issues with context.temp_allocator when csv.iterator_next reuses its buffer across loops.
    csv.reader_init(&reader, stream, context.allocator)

    rows: [dynamic][]string // dynamic array will use context.allocator by default
    csv_err: csv.Error
    for {
        row: []string
        row, _, csv_err, _ = csv.iterator_next(&reader)

        if csv_err == .EOF {
            break // End of file
        }
        if csv_err != nil {
            log.errorf("Error reading CSV: %v", csv_err)
            // Clean up partially read rows on error
            for r in rows {
                delete(r)
            }
            delete(rows)
            return nil, .Invalid_CSV_Format
        }
        row_copy := make([]string, len(row))
        for i := 0; i < len(row); i += 1 {
            row_copy[i] = strings.clone(row[i]) // `strings.clone` also allocates with context.allocator
        }
        append(&rows, row_copy)
    }
    if len(rows) == 0 {
        // Returning nil and .None might imply success with no data, which might be confusing
        return nil, .No_Content
    }
    return rows[:], .None
}

// write_file writes a 2D slice of strings to a CSV file at the given path.
write_file :: proc(path: string, data: [][]string) -> (err: Err) {
    // os.O_CREATE: create the file if it doesn't exist
    // os.O_TRUNC: truncate the file to zero length if it exists
    file, os_err := os.open(path, os.O_WRONLY | os.O_TRUNC | os.O_CREATE, 0o666)
    if os_err != os.ERROR_NONE {
        log.errorf("failed to create/open CSV file for writing '%s': %v", path, os_err)
        return .File_Error
    }
    defer os.close(file)

    stream := os.stream_from_handle(file)
    writer: csv.Writer
    csv.writer_init(&writer, stream)

    for row in data {
        csv.write(&writer, row)
    }
    csv.writer_flush(&writer)

    return .None
}

// struct_to_header_row generates a header row from struct tags.
struct_to_header_row :: proc(val: $T) -> (row: []string, err: Err) {
    ti := runtime.type_info_base(type_info_of(T))
    s, ok := ti.variant.(runtime.Type_Info_Struct)
    if !ok {
        log.errorf("Error: val is not a struct type, got %v", ti.variant)
        return nil, .Bad_Parameter
    }
    headers: [dynamic]string
    defer delete(headers)

    for i:i32 = 0; i < s.field_count; i += 1 {
        tag_val, has_tag := get_tag_val(s.tags[i])
        if has_tag {
            append(&headers, tag_val)
        }
    }
    if len(headers) == 0 {
        log.warnf("No fields with 'csv' tags found in struct %s", s.tags)
        return nil, .MissingTag
    }
    return slice.clone(headers[:]), .None
}


// struct_to_row converts a struct to a CSV row (slice of strings) using reflection
// and considering 'csv' tags for field order and naming.
struct_to_row :: proc(val: $T) -> (row: []string, err: Err) {
	ti := runtime.type_info_base(type_info_of(T))
	s, ok := ti.variant.(runtime.Type_Info_Struct)
	if !ok {
		log.errorf("Error: val is not a struct type, got %v", ti.variant)
		return nil, .Bad_Parameter
	}

	// Create a temporary slice to hold the row values
	temp_row: [dynamic]string
	temp_row_map := make(map[string]string) // store values by tag name for ordered insertion

	for i:i32 = 0; i < s.field_count; i += 1 {
		tag_val, has_tag := get_tag_val(s.tags[i])
		if !has_tag {
			log.debugf("No csv tag found for field %s, skipping", s.names[i])
			continue
		}

		field_value := reflect.struct_field_value_by_name(val, s.names[i])
		if field_value.data == nil {
			log.warnf("Field %s has nil value, treating as empty string", s.names[i])
			temp_row_map[tag_val] = ""
			continue
		}

		field_str: string
        a := any{field_value.data, field_value.id}
		switch v_typ in a {
		case string:
			field_str = v_typ
		case ^string:
			if v_typ != nil { field_str = v_typ^ }
		case i32:
			field_str = fmt.tprintf("%d", v_typ)
		case ^i32:
			if v_typ != nil { field_str = fmt.tprintf("%d", v_typ^) }
		case i64:
			field_str = fmt.tprintf("%d", v_typ)
		case ^i64:
			if v_typ != nil { field_str = fmt.tprintf("%d", v_typ^) }
		case f32:
			field_str = fmt.tprintf("%f", v_typ)
		case ^f32:
			if v_typ != nil { field_str = fmt.tprintf("%f", v_typ^) }
		case f64:
			field_str = fmt.tprintf("%f", v_typ)
		case ^f64:
			if v_typ != nil { field_str = fmt.tprintf("%f", v_typ^) }
		case bool:
			field_str = "false"
			if v_typ { field_str = "true" }
		case ^bool:
			if v_typ != nil {
				field_str = "false"
				if v_typ^ { field_str = "true" }
			}
		case time.Time:
			t := v_typ
			val_str, ok := time.time_to_rfc3339(t)
			if !ok {
				log.errorf("Failed to convert time.Time to RFC3339 string for field %s", s.names[i])
				return nil, .Parsing_Failed
			}
			field_str = val_str
			// defer delete(val_str)
		case ^time.Time:
			if v_typ != nil {
				t := v_typ^
				val_str, ok := time.time_to_rfc3339(t)
				if !ok {
					log.errorf("Failed to convert ^time.Time to RFC3339 string for field %s", s.names[i])
					return nil, .Parsing_Failed
				}
				field_str = val_str
				// defer delete(val_str)
			}
		case:
			log.warnf("Unsupported type for field %s (%v), attempting string conversion", s.names[i], field_value.id)
			field_str = fmt.tprintf("%v", field_value) // Fallback to generic string conversion
		}
		temp_row_map[tag_val] = field_str
	}

	if len(temp_row_map) == 0 {
		log.warnf("No fields with 'csv' tags found in struct %s", s.tags)
		return nil, .MissingTag
	}

	// Ensure the order of fields in the row matches the order of tags in the struct
	for i:i32 = 0; i < s.field_count; i += 1 {
		tag_val, has_tag := get_tag_val(s.tags[i])
		if has_tag {
			append(&temp_row, temp_row_map[tag_val])
		}
	}

	return temp_row[:], .None
}

// row_to_struct converts a CSV row (slice of strings) to a struct using reflection.
// It matches CSV columns to struct fields based on eg csv:"name" tags and a set of column names.
// If a column name field is not found in the struct, it logs a warning and skips that field.
row_to_struct :: proc(row: []string, dst_ptr: ^$T, column_names: []string) -> (err: Err) {
	if row == nil || dst_ptr == nil {
		log.error("Error: row or destination struct pointer is nil")
		return .Bad_Parameter
	}

	ti := runtime.type_info_base(type_info_of(T))
	s, ok := ti.variant.(runtime.Type_Info_Struct)
	if !ok {
		log.errorf("Error: destination is not a struct type, got %v", ti.variant)
		return .Bad_Parameter
	}

    for i:i32; i < s.field_count; i += 1 {
        tag_val, has_tag := get_tag_val(s.tags[i])
        if !has_tag {
            log.debug("No db tag found for field", i, "skipping")
            continue
        }
        tag_val_cstr := strings.clone_to_cstring(tag_val)
        if tag_val_cstr == nil {
            log.errorf("Failed to convert db_tag '%s' to cstring for field '%s'", tag_val, tag_val)
            return .Allocation_Error 
        }
		defer delete(tag_val_cstr)
        val := row[i]
        if len(val) == 0 {
            log.warnf("Empty value for field '%s', skipping", tag_val)
            continue
        }
        fields := reflect.struct_field_types(T)
        f := reflect.struct_field_value_by_name(dst_ptr^, s.names[i])
        switch fields[i].id {
        case i32:
            new_int, ok := strconv.parse_int(val)
            if !ok {
                log.errorf("Failed to parse i32 from string: '%s'", val)
                return .Parsing_Failed
            }
            (^i32)(f.data)^ = i32(new_int)
        case ^i32:
            ptr := new(i32)
            ptr^ = 0
            new_int, ok := strconv.parse_int(val)
            if !ok {
                log.errorf("Failed to parse i32 from string: '%s'", val)
                return .Parsing_Failed
            }
            ptr^ = i32(new_int)
            (^(^i32))(f.data)^ = ptr
        case i64:
            new_i64, ok := strconv.parse_i64(val)
            if !ok {
                log.errorf("Failed to parse i64 from string: '%s'", val)
                return .Parsing_Failed
            }
            (^i64)(f.data)^ = new_i64
        case ^i64:
            ptr := new(i64)
            ptr^ = 0
            new_i64, ok := strconv.parse_i64(val)
            if !ok {
                log.errorf("Failed to parse i64 from string: '%s'", val)
                return .Parsing_Failed
            }
            ptr^ = new_i64
            (^(^i64))(f.data)^ = ptr
        case f64:
            new_f64, ok := strconv.parse_f64(val)
            if !ok {
                log.errorf("Failed to parse f64 from string: '%s'", val)
                return .Parsing_Failed
            }
            (^f64)(f.data)^ = new_f64
        case ^f64:
            ptr := new(f64)
            ptr^ = 0.0
            new_f64, ok := strconv.parse_f64(val)
            if !ok {
                log.errorf("Failed to parse f64 from string: '%s'", val)
                return .Parsing_Failed
            }
            ptr^ = new_f64
            (^(^f64))(f.data)^ = ptr
        case string:
            (^string)(f.data)^ = val
        case ^string:
            ptr := new(string)
            ptr^ = strings.clone(val)
            (^(^string))(f.data)^ = ptr
        case bool:
            if val == "true" {
                (^bool)(f.data)^ = true
            } else if val == "false" {
                (^bool)(f.data)^ = false
            } else {
                log.errorf("Failed to parse bool from string: '%s'", val)
                return .Parsing_Failed
            }
        case ^bool:
            ptr := new(bool)
            ptr^ = false
            if val == "true" {
                ptr^ = true
            } else if val == "false" {
                ptr^ = false
            } else {
                log.errorf("Failed to parse bool from string: '%s'", val)
                return .Parsing_Failed
            }
            (^(^bool))(f.data)^ = ptr
        case time.Time:
            t, consumed := time.rfc3339_to_time_utc(val)
            fmt.printf("Parsed time: %v, consumed: %d/%d\n", t, consumed, len(val))
            if consumed != len(val) {
                log.errorf("Failed to parse time from string: '%s'", val)
                return .Time_Format_Error
            }
            (^time.Time)(f.data)^ = t
        case ^time.Time:
            ptr := new(time.Time)
            t, consumed := time.rfc3339_to_time_utc(val)
            if consumed != len(val) {
                log.errorf("Failed to parse time from string: '%s'", val)
                return .Time_Format_Error
            }
            ptr^ = t
            (^(^time.Time))(f.data)^ = ptr
        }
    }
    return .None
}

// get_tag_val extracts the value of the "csv" tag from a struct field's tag string.
// Example: `csv:"column_name"`
get_tag_val :: proc(tag: string) -> (tag_value: string, has_csv_tag: bool) {
    // For simplicity, we directly check for "csv:" prefix and quotes
    if strings.has_prefix(tag, `csv:"`) && strings.has_suffix(tag, `"`) {
        return tag[5:len(tag)-1], true
    }
    return "", false
}
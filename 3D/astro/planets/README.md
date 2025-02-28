# PlanetSimulator_usingRaylib

Welcome to the **3D Model of Planets** project! This project generates a 3D model of planets using topographic features and textures, primarily focusing on Earth. The model allows for various customizations and simulations to create an accurate and dynamic representation of planets.

![Demo GIF](https://github.com/vb8146649/PlanetSimulator_usingRaylib/blob/main/preview.gif)

- [Watch the demo video](https://youtu.be/WQ0DoUXU-0g?si=nfuv8UAX7jTqRRaK)

## Some Available Maps:

<img src="https://github.com/vb8146649/PlanetSimulator_usingRaylib/blob/main/src/mercury/4096.png" height=350 width=700>

<img src="https://github.com/vb8146649/PlanetSimulator_usingRaylib/blob/main/src/GFSR/1.png" height=350 width=700>

<img src="https://github.com/vb8146649/PlanetSimulator_usingRaylib/blob/main/static_images/monthly/earth-night/1.jpg" height=350 width=700>

<img src="https://github.com/vb8146649/PlanetSimulator_usingRaylib/blob/main/src/milkyway/constillation.jpg" height=350 width=700>

- **Venus** , **Saturn**, etc.

## Features

- **Topographic and Texture Mapping**: Generates a 3D model of the planet using topographic data and textures.
- **Customizable Radius**: Adjust the radius of the planet model.
- **Mountain Prominence**: Make mountains pop by increasing their prominence.
- **Landmass Altitude**: Increase the altitude of all landmasses to differentiate from the sea.
- **Resolution Adjustment**: Change the resolution of the model for more detailed or simplified views.
- **Seasons Simulation**: Simulate seasons on the planet model.
- **Atmosphere and Clouds**: Add an atmosphere and clouds based on NASA satellite data.
- **Free Camera Mode**: View the model in a free camera mode for an immersive experience.
- **Real-time Simulation**: All changes and simulations happen in real-time.
- **Additional Datasets**: Includes hard-to-obtain datasets for trying out models of other planets.
- **Save 3d models**:Save the 3d model according to your preferences.

## Future Plans

- **Moons Simulation**: Simulate moons orbiting the planets.
- **Random Cloud Map Generator**: Add a feature to generate random cloud maps.
- **Coming Soon...**

## Getting Started

To get started with the project, follow these steps:

### Prerequisites

- C++ compiler
- [raylib](https://www.raylib.com/) library
- [Visual Studio Code](https://code.visualstudio.com/) (or any preferred IDE)

### Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/vb8146649/PlanetSimulator_usingRaylib
    cd PlanetSimulator_usingRaylib
    ```

2. Install dependencies:
    - Follow the instructions on the [raylib website](https://www.raylib.com/) to install raylib.
    - Ensure your C++ compiler is set up correctly.
    - Make sure you have `raygui.h` and update it's location in the `common.h`.

3. Build the project:
    - Open the project in your IDE (e.g., Visual Studio Code).
    - Build the project using the build tools provided by your IDE.

### Usage

Run the executable generated after building the project. You will see a window with the 3D model of the planet.

- Use the controls to adjust the radius, mountain prominence, landmass altitude, and resolution.
- Toggle seasons and atmosphere to see the changes in real-time.
- Switch to free camera mode to explore the model from different angles.

## Changing File Location for Different Planets

To create models of other planets, you need to update the file locations in `main.cpp`. There are four variables corresponding to topography, texture, initial file location for clouds, and initial file location for seasons. 

1. **Open `main.cpp`**:
    - Locate the file `main.cpp` in your project directory and open it in your text editor or IDE.

2. **Update Variables**:
    - Find the following variables in `main.cpp`:
      ```cpp
      std::string topographymap = "path/to/topography.png";
      std::string texturemap = "path/to/texture.png";
      std::string cloudmaploc = "path/to/clouds/cloud/";
      std::string seasonsmaploc = "path/to/seasons/season/";
      ```
    - Update these variables with the paths to your new planet data files. Ensure that the images for clouds and seasons are named in sequence (e.g., 1.png, 2.png) and use the correct file names to specify the ending and starting numbers.

3. **Ensure File Format**: 
    - Use only png file formats for image and texture.

4. **Ensure Numbered Filenames**:
    - Make sure that the image names for clouds and seasons are in numerical order. For example, `1.png`, `2.png`, etc. The program will use these numbers to load the correct files.

5. **Save and Rebuild**:
    - Save your changes to `main.cpp` and rebuild the project using your IDE's build tools.

## Datasets

The repository includes various datasets for different planets. These datasets are rare and hard to obtain, providing an opportunity to explore and model other planets besides Earth.

## Contributing

If you have any suggestions or improvements, feel free to create an issue or submit a pull request. Contributions are always welcome!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [raylib](https://www.raylib.com/)
- NASA for providing satellite data

---

Hope you enjoy exploring and simulating planets with this project! For any queries, feel free to reach out.



## [Ben Houston's Ultimate Guide to 3D File Formats](https://www.threekit.com/blog/gltf-vs-fbx-which-format-should-i-use)


## [Mixamo to Blender to Raylib](https://github.com/EscherechiaColi/tuto_raylib_animation/tree/main) translated:

Hello! After taking a quick look at the topic, I noticed that implementing animations in **Raylib** can be a bit tricky. I looked into it and I’m offering you a quick tutorial to explain how to download an animation from **mixamo**, import it into **Blender**, and export it in a format accepted by **Raylib**.

# Mixamo

The site offers many 3D animations available for download  [https://www.mixamo.com/#/](https://www.mixamo.com/#/)

![](assets/mixamo.png)

Search for an animation you’re interested in:

![](assets/mixamo_search.png)

Click on the result and watch the animation play on the right.
If you’re satisfied with it, you can download it:

![](assets/mixamo_download.png)

Click the download button, and you should see the following dialog window:

![](assets/mixamo_download_settings.png)

Do not change anything, and press the **Download** button.

# Blender

Blender is a free and open-source 3D editor. You can get it here:

[https://www.blender.org/](https://www.blender.org/)

Once downloaded and installed, launch it:

![](assets/blender.png)

Delete the cube (click it and press *Delete*), then import your newly acquired animation:

![](assets/blender_import.png)

![](assets/blender_post_import.png)

You then need to reset the scale back to its original value. To do so, click on **Armature** and press **ALT + S**:

![](assets/blender_reset_scale.png)

For this tutorial we will use .iqm as our 3D model format compatible with Raylib, so you'll need to install an add-on that allows Blender to export an object and its animation. Go to this **GitHub** page:

[https://github.com/lsalzman/iqm](https://github.com/lsalzman/iqm)

And click here:

![](assets/BlenderIQMExporter.png)

Once inside this folder, download the Python file:

![](assets/blender_iqm_exporter.png)

Now go back to Blender. We need to install the add-on.
To do this, click on **Edit > Preferences**:

![](assets/blender_addon.png)

Then click **Install** as shown here:

![](assets/blender_addon_install.png)

In the window that opens, find the Python file you downloaded, and click **Install Add-on**:

![](assets/blender_addon_install_from_file.png)

If it doesn’t appear immediately, search for “iqm” in the search bar and make sure the add-on “Import-Export: Export Inter-Quake Model (.iqm/.iqe)” is checked:

![](assets/blender_addon_checked.png)

You can then export the model as **.iqm**:

![](assets/blender_export_as_iqm.png)

You will need to perform two exports for everything to work correctly with Raylib.

The first export is done as shown below.
For this one, **DO NOT CHANGE THE SETTINGS ON THE RIGHT**:

![](assets/blender_export_iqm_untouched.png)

Once that is done, we reach the slightly more technical part: exporting the animation.

To do this, you must rename the animation inside **Blender’s object hierarchy**.
Expand **Armature > Animation** and change the name “mixamo[…]” to the name you want for your animation:

![](assets/blender_change_animation_name.png)

Then click the icon indicated by the left arrow below, which will open the following menu, and click **Dope Sheet**:

![](assets/blender_check_keyframes.png)

In the new window, scroll to the right to find the last **keyframe** of your animation (as you can see, the animation is represented by a green line with yellow dots representing keyframes). Note the number of the last keyframe (here 372):

![](assets/blender_find_last_keyframe.png)

You can now export the animation.
To do so, repeat the previous **.iqm** export process. Once you’ve clicked **File > Export > .iqm**, you must change the file name (usually the model's name + “_animation” or “anim”), then add the line indicated by the right arrow, using the following format:

**ANIMATION_NAME : ANIMATION_START_FRAME (always 1) : ANIMATION_END_FRAME (as seen above) : FRAMES_PER_SECOND (30 recommended) : 1 IF YOU WANT THE ANIMATION TO LOOP, 0 OTHERWISE**

The **separator** between each element is a **":"** (example below):

![](assets/blender_export_animation.png)

# Raylib

Now that your files are ready, here’s how to use them with Raylib.
Go to the **Raylib** website:

[https://www.raylib.com/](https://www.raylib.com/)

Click on “Examples”, then “Models”, then on the animation with the yellow guy:

![](assets/raylib_example.png)

This code is located in the **models_animation.c** file under **raylib/examples/models** after downloading Raylib.
In this code, replace the path indicated by **1** with the one to your model file (`gangnam.iqm`), comment the lines indicated by the arrows, and replace the path indicated by **2** with the one to your animation file (`gangnam_anim.iqm`):

![](assets/raylib_code1.png)

![](assets/raylib_code2.png)

Once that’s done, compile everything (the method depends on your installation — refer to the Raylib documentation!), then launch the **models_animation** binary.
You’ll get the following window, but don’t panic, it’s just extremely zoomed in:

![](assets/raylib_exec_zoomed.png)

Zoom out using your touchpad or mouse wheel, and there you go:

![](assets/raylib_exec_unzoomed.png)

Aaaand… done! Hold **space** to play the animation!

## Fixed Timesteps

Having a universal ticker frees our program from it's dependency on FPS which can be highly variable. For instance, take character properties such as walk speed or attack rate and it becomes obvious why those should not be linked to FPS, but to a more constant and predictable tick value like BPM (beats per minute) for an easy transition into music theory, a primitive time keeping mechanic that has multiple uses.

- [Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep)] article

- [Fixed timestep without interpolation](https://jakubtomsu.github.io/posts/fixed_timestep_without_interpolation/)

- [Fixed Timestep Demo](https://github.com/jakubtomsu/fixed-timestep-demo) git
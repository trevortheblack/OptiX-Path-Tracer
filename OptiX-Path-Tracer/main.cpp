// ======================================================================== //
// Copyright 2018 Ingo Wald                                                 //
//                                                                          //
// Licensed under the Apache License, Version 2.0 (the "License");          //
// you may not use this file except in compliance with the License.         //
// You may obtain a copy of the License at                                  //
//                                                                          //
//     http://www.apache.org/licenses/LICENSE-2.0                           //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
// ======================================================================== //

#include <iostream>
#include <iomanip>
#include <chrono>
#include <cstdlib>

// Host include
// Host side constructors and functions. We also have OptiX 
// Programs(RT_PROGRAM) that act in the device side. Note 
// that we can use host functions as usual in these headers.
#include "host_includes/scenes.h"
//#include "host_includes/scene_parser.h"

optix::Context g_context;

// Clamp color values when saving to file
inline float clamp(float value) {
	return value > 1.0f ? 1.0f : value;
}

void renderFrame(int Nx, int Ny) {
  // Validate settings
  g_context->validate();

  // Launch ray generation program
  g_context->launch(/*program ID:*/0, /*launch dimensions:*/Nx, Ny);
}

optix::Buffer createFrameBuffer(int Nx, int Ny) {
  optix::Buffer pixelBuffer = g_context->createBuffer(RT_BUFFER_OUTPUT);
  pixelBuffer->setFormat(RT_FORMAT_FLOAT3);
  pixelBuffer->setSize(Nx, Ny);
  return pixelBuffer;
}

optix::Buffer createSeedBuffer(int Nx, int Ny) {
  optix::Buffer pixelBuffer = g_context->createBuffer(RT_BUFFER_OUTPUT);
  pixelBuffer->setFormat(RT_FORMAT_UNSIGNED_INT);
  pixelBuffer->setSize(Nx, Ny);
  return pixelBuffer;
}

int main(int ac, char **av) {
  // Create an OptiX context
  g_context = optix::Context::create();
  g_context->setRayTypeCount(1);
  g_context->setStackSize( 5000 ); // keep it under 10k, it's per core
  
  // Set main parameters
  int Nx = 4480;
  int Ny = 1080;
  const int samples = 100;
  int scene = 4;

  // set number of samples
  g_context["samples"]->setInt(samples);

  // Create and set the world and camera
  Camera camera;
  optix::Group world;

  //Parser(g_context, camera, "main.json");
  
  auto t0 = std::chrono::system_clock::now();
  std::string output;
  switch(scene) {
    case 0: 
      Nx = Ny = 1080;
      output = "output/royl/iow-";
      world = InOneWeekend(g_context, camera, Nx, Ny);
      break;
    case 1:
      Nx = Ny = 1080;
      output = "output/royl/moving-";
      world = MovingSpheres(g_context, camera, Nx, Ny);
      break;
    case 2:
      Nx = Ny = 1080;
      output = "output/royl/royl-";
      world = Cornell(g_context, camera, Nx, Ny);
      break;
    case 3:
      Nx = Ny = 1080;
      output = "output/royl/tnw-final-";
      world = Final_Next_Week(g_context, camera, Nx, Ny);
      break;
    case 4:
      Nx = Ny = 1080;
      output = "output/3D-models-";
      world = Test_Scene(g_context, camera, Nx, Ny);
      break;
    default:
      printf("Error: scene unknown.\n");
      system("PAUSE");
      return 1;
  }
  camera.set(g_context);
  g_context["world"]->set(world);
  auto t1 = std::chrono::system_clock::now();
  auto sceneTime = std::chrono::duration<double>(t1 - t0).count();
  printf("Done assigning scene data, which took %.2f seconds.\n", sceneTime);

  // Create a frame buffer
  optix::Buffer fb = createFrameBuffer(Nx, Ny);
  g_context["fb"]->set(fb);

  // Create a rng seed buffer
  optix::Buffer seed = createSeedBuffer(Nx, Ny);
  g_context["seed"]->set(seed);

  // Check OptiX scene build time
  auto t2 = std::chrono::system_clock::now();
  g_context["run"]->setInt(0);
  renderFrame(0, 0);
  auto t3 = std::chrono::system_clock::now();
  auto buildTime = std::chrono::duration<double>(t3 - t2).count();
  printf("Done building OptiX data structures, which took %.2f seconds.\n", buildTime);

  // Render scene
  auto t4 = std::chrono::system_clock::now();
  for(int i = 0; i < samples; i++) {
    g_context["run"]->setInt(i);
    renderFrame(Nx, Ny);
    printf("Progress: %.2f%%\r", (i * 100.f / samples));
  }
  auto t5 = std::chrono::system_clock::now();
  auto renderTime = std::chrono::duration<double>(t5 - t4).count();
  printf("Done rendering, which took %.2f seconds.\n", renderTime);
       
  // Save buffer to a PNG file
	unsigned char *arr = (unsigned char *)malloc(Nx * Ny * 3 * sizeof(unsigned char));
  const vec3f *cols = (const vec3f *)fb->map();

	for (int j = Ny - 1; j >= 0; j--)
		for (int i = 0; i < Nx; i++) {
      int col_index = Nx * j + i;
			int pixel_index = (Ny - j - 1) * 3 * Nx + 3 * i;

      // average matrix of samples
      vec3f col = cols[col_index] / float(samples);
  
      // gamma correction
      col = vec3f(sqrt(col.x), sqrt(col.y), sqrt(col.z));

      // from float to RGB [0, 255]
			arr[pixel_index + 0] = int(255.99 * clamp(col.x)); // R
			arr[pixel_index + 1] = int(255.99 * clamp(col.y)); // G
			arr[pixel_index + 2] = int(255.99 * clamp(col.z)); // B
    }

  output += std::to_string(samples) + ".png";
  stbi_write_png((char*)output.c_str(), Nx, Ny, 3, arr, 0);
  fb->unmap();

  system("PAUSE");

  return 0;
}


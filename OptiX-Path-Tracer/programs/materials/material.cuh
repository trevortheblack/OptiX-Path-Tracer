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

#pragma once

#include "../pdfs/pdf.cuh"
#include "../trigonometric.cuh"

RT_FUNCTION float schlick(float cosine, float ref_idx) {
  float r0 = (1.f - ref_idx) / (1.f + ref_idx);
  r0 = r0 * r0;
  return r0 + (1.f - r0) * pow((1.f - cosine), 5.f);
}

RT_FUNCTION float3 schlick(float3 r0, float cos) {
  float exponential = powf(1.f - cos, 5.f);
  return r0 + (make_float3(1.f) - r0) * exponential;
}

RT_FUNCTION float SchlickR0FromRelativeIOR(float eta) {
  // https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
  return ((eta - 1.f) * (eta - 1.f)) / ((eta + 1.f) * (eta + 1.f));
}

RT_FUNCTION bool refract(const float3& v, const float3& n, float ni_over_nt,
                         float3& refracted) {
  float3 uv = unit_vector(v);
  float dt = dot(uv, n);
  float discriminant = 1.f - ni_over_nt * ni_over_nt * (1.f - dt * dt);

  if (discriminant > 0.f) {
    refracted = ni_over_nt * (uv - n * dt) - n * sqrt(discriminant);
    return true;
  } else
    return false;
}

RT_FUNCTION bool SameHemisphere(const float3 a, const float3 b) {
  return a.y * b.y > 0.f;
}

RT_FUNCTION bool Transmit(float3 wm, float3 wi, float n, float3& wo) {
  float c = dot(wi, wm);
  if (c < 0.f) {
    c = -c;
    wm = -wm;
  }

  float root = 1.f - n * n * (1.f - c * c);
  if (root <= 0.f) return false;

  wo = (n * c - sqrt(root)) * wm - n * wi;
  return true;
}

RT_FUNCTION float convert_alpha(float roughness) {
  return pow(max(0.01f, roughness), 4.f);
}

RT_FUNCTION float convert_exp(float roughness) {
  return 2.0f / convert_alpha(roughness) - 2.0f;
}

RT_FUNCTION float3 Spherical_Vector(float sintheta, float costheta, float phi) {
  float x = sintheta * cos(phi);
  float y = costheta;
  float z = sintheta * sin(phi);
  return make_float3(x, y, z);
}

// Sampling Blinn - reference:
// https://github.com/JerryCao1985/SORT/blob/547286d552dc0e555d8144fd28bfae58535ad0d8/src/bsdf/microfacet.cpp
// https://github.com/JerryCao1985/SORT/blob/547286d552dc0e555d8144fd28bfae58535ad0d8/src/bsdf/microfacet.h

RT_FUNCTION float3 Blinn_Sample(float u, float v, float nu, float nv) {
  float expU = convert_exp(nu);
  float expV = convert_exp(nv);
  float expUV = sqrt((expU + 2.0f) / (expV + 2.0f));

  float phi = 2.f * PI_F * v;
  if (expU != expV) {
    int offset[5] = {0, 1, 1, 2, 2};
    int i = v == 0.25 ? 0 : (int)(v * 4.f);
    phi = std::atan(expUV * std::tan(phi)) + offset[i] * PI_F;
  }

  float sin_phi_h = sin(phi);
  float sin_phi_h_sq = sin_phi_h * sin_phi_h;
  float alpha = expU * (1.f - sin_phi_h_sq) + expV * sin_phi_h_sq;
  float cos_theta = pow(u, 1.f / (alpha + 2.f));
  float sin_theta = sqrt(ffmax(0.f, 1.f - cos_theta * cos_theta));

  return Spherical_Vector(sin_theta, cos_theta, phi);
}

// "Returns probability of facet with given normal"
RT_FUNCTION float Blinn_Density(float3& normal, float nu, float nv) {
  float expU = convert_exp(nu);
  float expV = convert_exp(nv);
  float expUV = sqrt((expU + 2.0f) * (expV + 2.0f));

  float NoH = AbsCosTheta(normal);

  float exponent = (1 - Sin2Phi(normal)) * expU;
  exponent += Sin2Phi(normal) * expV;

  return expUV * pow(NoH, exponent) / (1.f / 2 * PI_F);
}

// "PDF of sampling a specific normal direction"
RT_FUNCTION float Blinn_PDF(float3& normal, float nu, float nv) {
  return Blinn_Density(normal, nu, nv) * AbsCosTheta(normal);
}
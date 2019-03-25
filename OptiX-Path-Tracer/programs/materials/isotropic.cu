#include "material.cuh"

/*! the implicit state's ray we will intersect against */
rtDeclareVariable(Ray, ray, rtCurrentRay, );

/*! the per ray data we operate on */
rtDeclareVariable(PerRayData, prd, rtPayload, );
rtDeclareVariable(rtObject, world, , );

/*! the attributes we use to communicate between intersection programs and hit
 * program */
rtDeclareVariable(HitRecord, hit_rec, attribute hit_rec, );

/*! and finally - that particular material's parameters */
rtDeclareVariable(rtCallableProgramId<float3(float, float, float3, int)>,
                  sample_texture, , );

RT_PROGRAM void closest_hit() {
  // get material params from buffer
  int texIndex = hit_rec.index;

  // assign material params to prd
  prd.matType = Isotropic_BRDF;
  prd.isSpecular = true;
  prd.scatterEvent = rayGotBounced;
  prd.direction = random_on_unit_sphere(prd.seed);

  float3 color = sample_texture(hit_rec.u, hit_rec.v, hit_rec.p, texIndex);
  prd.matParams.attenuation = color;

  // assign hit params to prd
  prd.origin = hit_rec.p;
  prd.geometric_normal = hit_rec.geometric_normal;
  prd.shading_normal = hit_rec.shading_normal;
}

RT_CALLABLE_PROGRAM float3 BRDF_Sample(PDFParams &pdf, uint &seed) {
  pdf.direction = random_on_unit_sphere(seed);
  return pdf.direction;
}

RT_CALLABLE_PROGRAM float BRDF_PDF(PDFParams &pdf) { return 0.25 * PI_F; }

RT_CALLABLE_PROGRAM float3 BRDF_Evaluate(PDFParams &pdf) {
  return 0.25 * PI_F * pdf.matParams.attenuation;
}

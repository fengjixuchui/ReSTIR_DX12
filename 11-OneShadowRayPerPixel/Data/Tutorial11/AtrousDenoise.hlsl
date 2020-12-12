/* Shade pixel */

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gShadeImg;
RWTexture2D<float4> gShadeImgOutput;

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position) : SV_Target0
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	float width;
	float height;
	gShadeImgOutput.GetDimensions(width, height);

	float c_phi = 0.773;
	float n_phi = 0.052;
	float p_phi = 0.722;
	int nStep = 100;

	float3 nval = gWsNorm[pixelPos].xyz;
	float3 pval = gWsPos[pixelPos].xyz;

	float kernel[25] = { 0.0625, 0.0625, 0.0625, 0.0625, 0.0625,
					0.0625, 0.25,   0.25,  0.25,   0.0625,
					0.0625, 0.25,   0.375,  0.25,   0.0625,
					0.0625, 0.25,   0.25,  0.25,   0.0625,
					0.0625, 0.0625, 0.0625, 0.0625, 0.0625 };

	int2 offset[25] = { int2(-2, -2), int2(-2, -1), int2(-2, 0), int2(-2, 1), int2(-2, 2),
							int2(-1, -2), int2(-1, -1), int2(-1, 0), int2(-1, 1), int2(-1, 2),
							int2(0, -2), int2(0, -1), int2(0, 0), int2(0, 1), int2(0, 2),
							int2(1, -2),int2(1, -1), int2(1, 0), int2(1, 1), int2(1, 2),
							int2(2, -2), int2(2, -1), int2(2, 0), int2(2, 1), int2(2, 2) };

	for (int k = 0; ; k++) {
		int stepwidth = 1 << k;
		if (stepwidth * 5 > nStep) {
			break;
		}
		gShadeImg[pixelPos] = gShadeImgOutput[pixelPos]; // Pingpong

		float3 sum = float3(0.0, 0.0, 0.0);
		float3 cval = gShadeImg[pixelPos].xyz;
		float cum_w = 0.0;
		for (int i = 0; i < 25; i++) {
			int nx = pixelPos.x + offset[i][0] * stepwidth;
			int ny = pixelPos.y + offset[i][1] * stepwidth;
			if (nx >= width || ny >= height || nx < 0 || ny < 0) {
				continue;
			}
			uint2 neighborPos = uint2((uint)nx, (uint)ny);

			float3 ctmp = gShadeImg[neighborPos].xyz;
			float3 t = cval - ctmp;
			float dist2 = dot(t, t);
			float c_w = min(exp(-(dist2) / c_phi), 1.0);

			float3 ntmp = gWsNorm[neighborPos].xyz;
			t = nval - ntmp;
			dist2 = max(dot(t, t), 0.0f);
			float n_w = min(exp(-(dist2) / n_phi), 1.0);

			float3 ptmp = gWsPos[neighborPos].xyz;
			t = pval - ptmp;
			dist2 = dot(t, t);
			float p_w = min(exp(-(dist2) / p_phi), 1.0);

			float weight = c_w * n_w * p_w;
			sum += ctmp * weight * kernel[i];
			cum_w += weight * kernel[i];
		}
		//DeviceMemoryBarrierWithGroupSync();
		gShadeImgOutput[pixelPos] = float4(sum / cum_w, 0.0);
	}


	return gShadeImgOutput[pixelPos];
}
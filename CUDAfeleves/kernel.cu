#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <stdio.h>
using namespace std;

#define IMG_INPUT "C:\\Users\\Bence\\source\\repos\\CUDAfeleves\\Kepek\\input1.bmp"

#define IMG_OUTPUT "C:\\Users\\Bence\\source\\repos\\CUDAfeleves\\Kepek\\output.bmp"
#define IMG_OUTPUT2 "C:\\Users\\Bence\\source\\repos\\CUDAfeleves\\Kepek\\output2.bmp"

//4000*4000
//3613*5420
#define IMG_HEADER 1078
#define IMG_WIDTH 4000
#define IMG_HEIGHT 4000
#define Channel 3
	
#define ImgSize (IMG_HEADER+IMG_WIDTH*IMG_HEIGHT*Channel)
//a csík issue a dimSize-al lesz kapcsolatban
#define dimSize  32
#define FilterSize 3
#define tileSize (dimSize - ((FilterSize/2)*2))

__device__ unsigned char dev_imgin[IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel];
__device__ unsigned char dev_img_result[IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel];

__constant__ int dev_filter[FilterSize*FilterSize];

__global__ void GrayPicMultipleBlocks() {

	int x = blockIdx.x * blockDim.x + threadIdx.x;
	int y = blockIdx.y * blockDim.y + threadIdx.y;
	int actual = IMG_WIDTH * Channel * y + Channel * x;


	if (IMG_HEADER + actual+Channel-1<ImgSize)
	{
		int tmp = 0;
		for (int i = 0; i < Channel; i++)
		{
			tmp += (int)dev_imgin[IMG_HEADER + actual + i];
		}
		tmp /= Channel;
		for (int i = 0; i < Channel; i++)
		{
			dev_img_result[IMG_HEADER + actual + i]=(unsigned char)tmp;
		}

		

	}
	//if (true)
	//{
	//	int tmp = 0;
	//	tmp += (int)dev_img[IMG_HEADER + actualr];
	//	tmp += (int)dev_img[IMG_HEADER + actualg];
	//	tmp += (int)dev_img[IMG_HEADER + actualb];
	//	tmp /= 3;
	//	dev_img[IMG_HEADER + actualr]= (unsigned char)tmp;
	//	dev_img[IMG_HEADER + actualg]= (unsigned char)tmp;
	//	dev_img[IMG_HEADER + actualb]= (unsigned char)tmp;
	//}


}



__global__ void AnyFilter() {


	__shared__ int shr_Filter[FilterSize][FilterSize];
	if ((threadIdx.x<FilterSize) && (threadIdx.y<FilterSize))
	{
		shr_Filter[threadIdx.y][threadIdx.x] = dev_filter[threadIdx.y*FilterSize+threadIdx.x];
	}
	__syncthreads();

	__shared__ unsigned char shr_CMatrix[dimSize][dimSize * Channel];
	


	

		int xout = (tileSize * blockIdx.x) + threadIdx.x;
		int yout = (tileSize * blockIdx.y) + threadIdx.y;

		if (yout < IMG_HEIGHT && xout < IMG_WIDTH)
		{

			int ymatrix = yout - (FilterSize / 2);
			int xmatrix = xout - (FilterSize / 2);

			//int actual = IMG_WIDTH * Channel * y_i + Channel * x_i;


			if ((0 <= ymatrix) && (ymatrix < IMG_HEIGHT) && (0 <= xmatrix) && (xmatrix < IMG_WIDTH))
			{
				for (int i = 0; i < Channel; i++)
				{


					shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = dev_imgin[IMG_HEADER + (IMG_WIDTH * Channel * ymatrix) + (Channel * xmatrix) + i];
				}
			}
			else
			{
				//Feltoltes az utolso ertekkel
				if (0>ymatrix)
				{
					for (int i = 0; i < Channel; i++)
					{
						int actual = IMG_HEADER + (IMG_WIDTH * Channel * 0) + (Channel * xmatrix) + i;
						shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = dev_imgin[actual];

					}
				}
				else if (IMG_HEIGHT<=ymatrix)
				{
					for (int i = 0; i < Channel; i++)
					{
						int actual = IMG_HEADER + (IMG_WIDTH * Channel * (IMG_HEIGHT-1)) + (Channel * xmatrix) + i;
						shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = dev_imgin[actual];

					}
				}
				else if (0>xmatrix)
				{
					for (int i = 0; i < Channel; i++)
					{
						int actual = IMG_HEADER + (IMG_WIDTH * Channel * ymatrix) + (Channel * 0) + i;
						shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = dev_imgin[actual];

					}
				}
				else if (IMG_WIDTH<=xmatrix)
				{
					for (int i = 0; i < Channel; i++)
					{
						int actual = IMG_HEADER + (IMG_WIDTH * Channel * ymatrix) + (Channel * IMG_WIDTH-1) + i;
						shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = dev_imgin[actual];

					}
				}

				//feltoltes c szammal
				//for (int i = 0; i < Channel; i++)
				//{
				//	shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = 0;
				//	//shr_CMatrix[threadIdx.y][(threadIdx.x * Channel) + i] = 1;
				//}
			}


			__syncthreads();

			int sum[3] = { 0,0,0 };

			if (threadIdx.x < tileSize && threadIdx.y < tileSize)
			{
				for (int i = 0; i < FilterSize; i++)
				{
					for (int j = 0; j < FilterSize; j++)
					{
						for (int c = 0; c < Channel; c++)
						{
							int tmp = ((int)shr_CMatrix[threadIdx.y + i][((threadIdx.x + j) * Channel) + c] * shr_Filter[i][j]);
							sum[c] += tmp;


							//sum[c] += (int)shr_CMatrix[threadIdx.y + i][((threadIdx.x + j) * Channel) + c];


						}

					}
				}
			}

			//Blur effect-hez
			//for (size_t i = 0; i < Channel; i++)
			//{
			//	sum[i] /= 256;
			//}
			
			

			if (threadIdx.x < tileSize && threadIdx.y < tileSize)
			{

				for (int i = 0; i < Channel; i++)
				{
					int actual = IMG_HEADER + (IMG_WIDTH * Channel * yout) + (Channel * xout) + i;

					dev_img_result[actual] = (unsigned char)sum[i];
				}
			}
		}

	




}




int main()
{

	unsigned char* img;
	unsigned char* host_image;
	FILE* f_input_img, * f_output_img;
	//int host_filter[FilterSize * FilterSize] = {1,4,6,4,1,4,16,24,16,4,6,24,36,24,6,4,16,24,16,4,1,4,6,4,1};
	
	//int host_filter[FilterSize * FilterSize] = { 1, 0, 1, 0,5,0 , 1,0,1 };
	//int host_filter[FilterSize * FilterSize] = { 0, -1, 0, -1,4,-1 ,0,-1,0 };
	int host_filter[FilterSize * FilterSize] = { -1, -1, -1, -1,8,-1 , -1,-1,-1 };
	//int host_filter[FilterSize * FilterSize] = { 0, 0, 0, 1, 0, 0, 0,0,0};
	// 
	// 
	// 
	// Load image

	img = (unsigned char*)malloc(IMG_HEADER + sizeof(unsigned char) * IMG_WIDTH * IMG_HEIGHT * Channel);
	host_image = (unsigned char*)malloc(IMG_HEADER + sizeof(unsigned char) * IMG_WIDTH * IMG_HEIGHT * Channel);

	fopen_s(&f_input_img, IMG_INPUT, "rb");
	fread(img, 1, IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel, f_input_img);
	fclose(f_input_img);
	unsigned int tmpInt[IMG_HEADER];
	unsigned char tmpSet[IMG_HEADER];


	cudaMemcpyToSymbol(dev_filter, host_filter, FilterSize * FilterSize * sizeof(int));

	//ToDo: Memory copy H->D
	cudaMemcpyToSymbol(dev_imgin, img, IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel * sizeof(unsigned char));

	cudaMemcpyToSymbol(dev_img_result, img, IMG_HEADER * sizeof(unsigned char));
	//cudaMemcpyToSymbol(dev_img_result, img, IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel * sizeof(unsigned char));

	//cudaMemcpyToSymbol(dev_filter, host_filter, FilterSize * FilterSize * sizeof(int));



	dim3 grid_size((IMG_WIDTH + tileSize - 1) / tileSize  + 1, (IMG_HEIGHT + tileSize - 1) / tileSize + 1);
	dim3 block_size(dimSize, dimSize);
	/*GrayPicMultipleBlocks << <grid_size, dim3(dimSize, dimSize) >> > ();*/

	
	cudaDeviceSynchronize();

	AnyFilter<<<grid_size,block_size>>>();


	cudaDeviceSynchronize();

	cudaMemcpyFromSymbol(host_image, dev_img_result, IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel * sizeof(unsigned char));
	cudaDeviceSynchronize();



	fopen_s(&f_output_img, IMG_OUTPUT, "wb");
	fwrite(host_image, 1, IMG_HEADER + IMG_WIDTH * IMG_HEIGHT * Channel, f_output_img);
	fclose(f_output_img);
	free(img);
	free(host_image);

}

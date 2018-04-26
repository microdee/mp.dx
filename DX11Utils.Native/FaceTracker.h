#pragma once

#include "stdafx.h"

using namespace System;
using namespace System::IO;
using namespace System::Collections::Generic;
using namespace System::Runtime::InteropServices;

using namespace VVVV::Utils::VMath;


namespace mp {
	namespace dx {
		namespace Tracking {
			public ref class DetectedFace
			{
			public:
				property int X { int get(); };
				property int Y { int get(); };
				property int Width { int get(); };
				property int Height { int get(); };
				property int Neighbors { int get(); };
				property int Angle { int get(); };
				property array<Vector2D>^ Landmarks { array<Vector2D>^ get(); };
				bool HasLandmarks = false;

				DetectedFace();
				~DetectedFace() { }

				void Update(int * pResult, int ii);

			private:
				int _x;
				int _y;
				int _width;
				int _height;
				int _neighbors;
				int _angle;
				array<Vector2D>^ _landmarks;
			};

			public ref class FaceTrackerContext
			{
			public:
				FaceTrackerContext();
				~FaceTrackerContext();

				//property array<int>^ ResultBuffer { array<int>^ get(); };
				//property array<unsigned char>^ WorkBuffer { array<unsigned char>^ get(); };
				property array<DetectedFace^>^ Faces { array<DetectedFace^>^ get(); };
				property int FaceCount { int get(); };

				float Scale;
				int MinNeighbors;
				int MinObjectWidth;
				int MaxObjectWidth;
				int DoLandmarks;

				void DetectFrontal(array<unsigned char>^ image, int width, int height);
				void DetectFrontalSurveillance(array<unsigned char>^ image, int width, int height);
				void DetectMultiView(array<unsigned char>^ image, int width, int height);
				void DetectMultiViewReinforce(array<unsigned char>^ image, int width, int height);

			private:

				//array<int>^ _resultBuffer;
				array<unsigned char>^ _workBuffer;
				array<DetectedFace^>^ _faces;
				int _faceCount;

				void handleResult(int * pResult);

				[DllImport("libfacedetect.dll", EntryPoint = "?facedetect_frontal@@YAPEAHPEAE0HHHMHHHH@Z")]
				static int * facedetect_frontal(unsigned char * result_buffer, //buffer memory for storing face detection results, !!its size must be 0x20000 Bytes!!
					unsigned char * gray_image_data, int width, int height, int step, //input image, it must be gray (single-channel) image!
					float scale, //scale factor for scan windows
					int min_neighbors, //how many neighbors each candidate rectangle should have to retain it
					int min_object_width, //Minimum possible face size. Faces smaller than that are ignored.
					int max_object_width, //Maximum possible face size. Faces larger than that are ignored. It is the largest posible when max_object_width=0.
					int doLandmark); // landmark detection

				[DllImport("libfacedetect.dll", EntryPoint = "?facedetect_frontal_surveillance@@YAPEAHPEAE0HHHMHHHH@Z")]
				static int * facedetect_frontal_surveillance(unsigned char * result_buffer, //buffer memory for storing face detection results, !!its size must be 0x20000 Bytes!!
					unsigned char * gray_image_data, int width, int height, int step, //input image, it must be gray (single-channel) image!
					float scale, //scale factor for scan windows
					int min_neighbors, //how many neighbors each candidate rectangle should have to retain it
					int min_object_width, //Minimum possible face size. Faces smaller than that are ignored.
					int max_object_width, //Maximum possible face size. Faces larger than that are ignored. It is the largest posible when max_object_width=0.
					int doLandmark); // landmark detection

				[DllImport("libfacedetect.dll", EntryPoint = "?facedetect_multiview@@YAPEAHPEAE0HHHMHHHH@Z")]
				static int * facedetect_multiview(unsigned char * result_buffer, //buffer memory for storing face detection results, !!its size must be 0x20000 Bytes!!
					unsigned char * gray_image_data, int width, int height, int step, //input image, it must be gray (single-channel) image!
					float scale, //scale factor for scan windows
					int min_neighbors, //how many neighbors each candidate rectangle should have to retain it
					int min_object_width, //Minimum possible face size. Faces smaller than that are ignored.
					int max_object_width, //Maximum possible face size. Faces larger than that are ignored. It is the largest posible when max_object_width=0.
					int doLandmark); // landmark detection

				[DllImport("libfacedetect.dll", EntryPoint = "?facedetect_multiview_reinforce@@YAPEAHPEAE0HHHMHHHH@Z")]
				static int * facedetect_multiview_reinforce(unsigned char * result_buffer, //buffer memory for storing face detection results, !!its size must be 0x20000 Bytes!!
					unsigned char * gray_image_data, int width, int height, int step, //input image, it must be gray (single-channel) image!
					float scale, //scale factor for scan windows
					int min_neighbors, //how many neighbors each candidate rectangle should have to retain it
					int min_object_width, //Minimum possible face size. Faces smaller than that are ignored.
					int max_object_width, //Maximum possible face size. Faces larger than that are ignored. It is the largest posible when max_object_width=0.
					int doLandmark); // landmark detection
			};
		}
	}
}
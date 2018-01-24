#include "stdafx.h"
#include "FaceTracker.h"

#define DETECTARGPASS rbp, ip, width, height, width, Scale, MinNeighbors, MinObjectWidth, MaxObjectWidth, DoLandmarks
#define GETPOINTERS pin_ptr<unsigned char> mrbp = &_workBuffer[0]; unsigned char * rbp = mrbp; pin_ptr<unsigned char> mip = &image[0]; unsigned char * ip = mip;


using namespace mp::dx::Tracking;

DetectedFace::DetectedFace()
{
	_landmarks = gcnew array<Vector2D>(68);
}
void DetectedFace::Update(int * pResult, int ii)
{
	short * p = ((short*)(pResult + 1)) + 142 * ii;
	_x = p[0];
	_y = p[1];
	_width = p[2];
	_height = p[3];
	_neighbors = p[4];
	_angle = p[5];

	if(HasLandmarks)
	{
		for(int i=0; i<68; i++)
		{
			_landmarks[i] = Vector2D::Vector2D((double)p[6 + 2 * i], (double)p[6 + 2 * i + 1]);
		}
	}
}

int DetectedFace::X::get() { return _x; }
int DetectedFace::Y::get() { return _y; }
int DetectedFace::Width::get() { return _width; }
int DetectedFace::Height::get() { return _height; }
int DetectedFace::Neighbors::get() { return _neighbors; }
int DetectedFace::Angle::get() { return _angle; }
array<Vector2D>^ DetectedFace::Landmarks::get() { return _landmarks; }

FaceTrackerContext::FaceTrackerContext()
{
	Scale = 1.2f;
	MinNeighbors = 2;
	MinObjectWidth = 48;
	MaxObjectWidth = 0;
	DoLandmarks = -1;
	_workBuffer = gcnew array<unsigned char>(0x20000);
}

void FaceTrackerContext::handleResult(int * pResult)
{
	_faceCount = (pResult ? *pResult : 0);
	if(_faceCount == 0)
	{
		_faces = gcnew array<DetectedFace^>(0);
		return;
	}
	if(_faces == nullptr || _faces->Length != _faceCount)
	{
		delete _faces;
		_faces = gcnew array<DetectedFace^>(_faceCount);
		for (int i = 0; i < _faceCount; i++)
		{
			DetectedFace^ face = gcnew DetectedFace();
			face->HasLandmarks = DoLandmarks ? true : false;
			face->Update(pResult, i);
			_faces[i] = face;
		}
	}
	else
	{
		for (int i = 0; i < _faceCount; i++)
		{
			_faces[i]->HasLandmarks = DoLandmarks ? true : false;
			_faces[i]->Update(pResult, i);
		}
	}
}

void FaceTrackerContext::DetectFrontal(array<unsigned char>^ image, int width, int height)
{
	GETPOINTERS
		int * result = facedetect_frontal(DETECTARGPASS);
	handleResult(result);
}
void FaceTrackerContext::DetectFrontalSurveillance(array<unsigned char>^ image, int width, int height)
{
	GETPOINTERS
		int * result = facedetect_frontal_surveillance(DETECTARGPASS);
	handleResult(result);
}
void FaceTrackerContext::DetectMultiView(array<unsigned char>^ image, int width, int height)
{
	GETPOINTERS
		int * result = facedetect_multiview(DETECTARGPASS);
	handleResult(result);
}
void FaceTrackerContext::DetectMultiViewReinforce(array<unsigned char>^ image, int width, int height)
{
	GETPOINTERS
		int * result = facedetect_multiview_reinforce(DETECTARGPASS);
	handleResult(result);
}

//array<unsigned char>^ FaceTrackerContext::WorkBuffer::get() { return _workBuffer; }
array<DetectedFace^>^ FaceTrackerContext::Faces::get() { return _faces; }
int FaceTrackerContext::FaceCount::get() { return _faceCount; }
FaceTrackerContext::~FaceTrackerContext()
{
	delete _workBuffer;
	delete _faces;
}
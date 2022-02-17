#include "ofMain.h"
#include "ofApp.h"

int main(){
	#ifdef TARGET_RASPBERRY_PI
		ofSetupOpenGL(720,405,OF_WINDOW);
	#else
		ofSetupOpenGL(1280,720,OF_WINDOW);
	#endif
	ofRunApp(new ofApp());
}

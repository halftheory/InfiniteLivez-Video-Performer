#pragma once

#include "ofMain.h"

class ofApp : public ofBaseApp{

	public:
		void setup();
		void update();
		void draw();
		void exit();
		void keyPressed(int key);
		void windowResized(int w, int h);

		// screen.
		int frameRate = 30;
		#ifdef TARGET_RASPBERRY_PI
			bool fullscreen = true;
		#else
			bool fullscreen = false;
		#endif

    	// files.
		int dirDataSize = 0;

		// indexes.
		vector<string> indexesData;
		vector<int> indexesAlphabetical;
		int indexAlphabetical = 0;
		vector<int> indexesRandom;
		int indexRandom = 0;

		// video players.
		vector<ofVideoPlayer> videoPlayers;
		int videoPlayersIndex = 0;

		// setings.
		string playMode = "midi";
		string fileOrder = "alphabetical";
		int midiPhraseLength = 4;
		float bpm = 100.0;
		int beat = 0;

	private:
		void setScreenSize();
		void setVideoSize();
		void loadVideoPlayers();
		void triggerBeat(int intBeat = 0, string direction = "next");
		void triggerVideo(string direction = "next");
		void bpmStart();
		void bpmReset();

		// screen.
    	ofRectangle screenRect;
    	ofRectangle videoRect;

		// video players.
		#ifdef TARGET_RASPBERRY_PI
			int videoPlayersMax = 5;
		#else
			int videoPlayersMax = 30;
		#endif

		// midi.
		string strMididump = ofToDataPath("mididump.txt");
		ofBuffer bufMididump;
		ofFile fileMididump;

		// setings.
		int midiPhraseLengthDefault = 4;
		int midiPhraseLengthMin = 1;
		int midiPhraseLengthMax = 64;
		float bpmDefault = 100.0;
		float bpmMin = 10.0;
		float bpmMax = 300.0;
		float bpmInterval = 10.0;
		int bpmFrames = 15;
		int bpmFramesCounter = 0;
};

#include "ofApp.h"
#include <vector>
#include <algorithm>

void ofApp::setup(){
	// setup environment.
	#ifdef TARGET_RASPBERRY_PI
	    ofSetLogLevel(OF_LOG_SILENT);
	#else
	    ofSetLogLevel(OF_LOG_VERBOSE);
	#endif
	ofSetVerticalSync(true);
	ofSetFrameRate(frameRate);
	ofSetFullscreen(fullscreen);
	ofHideCursor();
	ofBackground(0,0,0);
	setScreenSize();

	// get files.
	ofDirectory dirData(".");
	vector<string> videoExtensions = {"avi","divx","dv","flv","m4v","mkv","mov","mp4","mpeg","mpg","ogv","ts","webm"};
	for(int i=0; i<(int)videoExtensions.size(); i++){
		dirData.allowExt(videoExtensions[i]);
		dirData.allowExt(ofToUpper(videoExtensions[i]));
	}
	dirData.listDir();
	if(dirData.size() == 0){
		ofLogNotice("ofApp::setup()", "No video files found. Exiting...");
		exit();
	}
	dirDataSize = dirData.size();
	dirData.sort();

	// setup indexes.
	indexesData.resize(dirDataSize);
	indexesAlphabetical.resize(dirDataSize);
	indexesRandom.resize(dirDataSize);
	for(int i=0; i<dirDataSize; i++){
		indexesData[i] = dirData.getPath(i);
		indexesAlphabetical[i] = i;
		indexesRandom[i] = i;
	}
	dirData.close();
	std::random_shuffle(indexesRandom.begin(), indexesRandom.end());

	// setup video players.
	int size = videoPlayersMax;
	if(dirDataSize < videoPlayersMax){
		size = dirDataSize;
	}
	videoPlayers.resize(size);
	for(int i=0; i<size; i++){
		videoPlayers[i].setPixelFormat(OF_PIXELS_RGB);
		videoPlayers[i].setLoopState(OF_LOOP_NORMAL);
		videoPlayers[i].setPaused(true);
	}
	float sizeHalf = float(size) / 2.0f;
	videoPlayersIndex = static_cast<int>(std::floor(sizeHalf));
	loadVideoPlayers();

	// start.
	triggerVideo("none");
}

//--------------------------------------------------------------
void ofApp::update(){
	// midi.
	if(playMode == "midi"){
		if(fileMididump.doesFileExist(strMididump)){
			bufMididump = ofBufferFromFile(strMididump);
			if(ofTrim(bufMididump.getText()) != ""){
				if(fileMididump.open(strMididump, ofFile::ReadWrite, false)){
					bufMididump.set(" ");
					if(fileMididump.writeFromBuffer(bufMididump)){
						triggerBeat();
					}
				}
			}
		}
	// bpm.
	}else if(playMode == "bpm"){
		bpmFramesCounter++;
		if(bpmFramesCounter >= bpmFrames){
			triggerBeat();
			bpmReset();
		}
	}

	// player.
	if(videoPlayers[videoPlayersIndex].isPlaying()){
    	videoPlayers[videoPlayersIndex].update();
    }
}

//--------------------------------------------------------------
void ofApp::draw(){
	if(videoPlayers[videoPlayersIndex].isPlaying()){
    	videoPlayers[videoPlayersIndex].draw(videoRect);
    }
}

//--------------------------------------------------------------
void ofApp::exit(){
	ofExit();
	//std::exit(0);
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){
	ofKeyEventArgs args;
	args.key = key;
	switch(args.key){
		case 'q':
			exit();
			break;

		case 'f':
			if(fullscreen){
				fullscreen = false;
			}else{
				fullscreen = true;
			}
			ofSetFullscreen(fullscreen);
			setScreenSize();
			break;

		case 'b':
			triggerBeat();
			break;

		case '1':
			playMode = "midi";
			break;

		case '2':
			if(playMode != "bpm"){
				bpmReset();
				bpmStart();
			}
			playMode = "bpm";
			break;

		case '3':
			if(fileOrder == "random"){
				fileOrder = "alphabetical";
			}else{
				fileOrder = "random";
			}
			loadVideoPlayers();
			triggerBeat(1, "none");
			break;

		case OF_KEY_LEFT:
			triggerBeat(1, "previous");
			break;

		case OF_KEY_RIGHT:
			triggerBeat(1);
			break;

		case OF_KEY_UP:
			if(playMode == "midi"){
				if(midiPhraseLength > midiPhraseLengthMin){
					midiPhraseLength = midiPhraseLength / (int)2;
				}
			}else if(playMode == "bpm"){
				if(bpm < bpmMax){
					bpm = bpm + bpmInterval;
					bpmStart();
				}
			}
			break;

		case OF_KEY_DOWN:
			if(playMode == "midi"){
				if(midiPhraseLength < midiPhraseLengthMax){
					midiPhraseLength = midiPhraseLength * (int)2;
				}
			}else if(playMode == "bpm"){
				if(bpm > bpmMin){
					bpm = bpm - bpmInterval;
					bpmStart();
				}
			}
			break;

		case OF_KEY_RETURN:
			if(playMode == "midi"){
				midiPhraseLength = midiPhraseLengthDefault;
			}else if(playMode == "bpm"){
				if(bpm != bpmDefault){
					bpm = bpmDefault;
					bpmReset();
					bpmStart();
				}
			}
			break;
	}
}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){
	setScreenSize();
}

//--------------------------------------------------------------
void ofApp::setScreenSize(){
	screenRect.setFromCenter(ofGetWidth() / 2.0f,
		ofGetHeight() / 2.0f,
		ofGetWidth(),
		ofGetHeight());
}

void ofApp::setVideoSize(){
    videoRect.setFromCenter(ofGetWidth() / 2.0f,
		ofGetHeight() / 2.0f,
		videoPlayers[videoPlayersIndex].getWidth(),
		videoPlayers[videoPlayersIndex].getHeight());
    videoRect.scaleTo(screenRect, OF_SCALEMODE_FIT); // OF_SCALEMODE_FILL
}

void ofApp::loadVideoPlayers(){
	int min;
	int max;
	int j;
	int k = 0;
	if(fileOrder == "random"){
		min = indexRandom - videoPlayersIndex;
		max = min + (int)videoPlayers.size();
		for(int i=min; i<max; i++){
			if(i < 0){
				j = dirDataSize + i;
			}else if(i >= dirDataSize){
				j = i - dirDataSize;
			}else{
				j = i;
			}
			videoPlayers[k].load(indexesData[indexesRandom[j]]);
			ofLogNotice("ofApp::loadVideoPlayers()", "Random " + ofToString(indexesData[indexesRandom[j]]));
			k++;
		}
	}else{
		min = indexAlphabetical - videoPlayersIndex;
		max = min + (int)videoPlayers.size();
		for(int i=min; i<max; i++){
			if(i < 0){
				j = dirDataSize + i;
			}else if(i >= dirDataSize){
				j = i - dirDataSize;
			}else{
				j = i;
			}
			videoPlayers[k].load(indexesData[indexesAlphabetical[j]]);
			ofLogNotice("ofApp::loadVideoPlayers()", "Alphabetical " + ofToString(indexesData[indexesAlphabetical[j]]));
			k++;
		}
	}
}

void ofApp::triggerBeat(int intBeat, string direction){
	if(intBeat == 0){
		beat++;
	}else{
		beat = intBeat;
	}
	// reset to 1?
	if(beat > 1){
		int max = 4;
		if(playMode == "midi"){
			max = midiPhraseLength;
		}
		if(beat > max){
			beat = 1;
		}
	}
	// change the file.
	if(beat == 1){
		triggerVideo(direction);
	}
}

void ofApp::triggerVideo(string direction){
	int videoPlayerNewIndex = -1;
	ofVideoPlayer videoPlayerNew;
	int last = (int)videoPlayers.size() - 1;
	// change indexes.
	if(fileOrder == "random"){
		if(direction == "next"){
			indexRandom++;
			if(indexRandom >= dirDataSize){
				indexRandom = indexRandom - dirDataSize;
			}
			videoPlayerNewIndex = indexRandom + ((int)videoPlayers.size() - videoPlayersIndex);
			if(videoPlayerNewIndex >= dirDataSize){
				videoPlayerNewIndex = videoPlayerNewIndex - dirDataSize;
			}
			videoPlayerNew = videoPlayers[0];
		}else if(direction == "previous"){
			indexRandom--;
			if(indexRandom < 0){
				indexRandom = dirDataSize + indexRandom;
			}
			videoPlayerNewIndex = indexRandom - videoPlayersIndex - 1;
			if(videoPlayerNewIndex < 0){
				videoPlayerNewIndex = dirDataSize + videoPlayerNewIndex;
			}
			videoPlayerNew = videoPlayers[last];
		}
		if(videoPlayerNewIndex >= 0){
			videoPlayerNew.load(indexesData[indexesRandom[videoPlayerNewIndex]]);
		}
	}else{
		if(direction == "next"){
			indexAlphabetical++;
			if(indexAlphabetical >= dirDataSize){
				indexAlphabetical = indexAlphabetical - dirDataSize;
			}
			videoPlayerNewIndex = indexAlphabetical + ((int)videoPlayers.size() - videoPlayersIndex);
			if(videoPlayerNewIndex >= dirDataSize){
				videoPlayerNewIndex = videoPlayerNewIndex - dirDataSize;
			}
			videoPlayerNew = videoPlayers[0];
		}else if(direction == "previous"){
			indexAlphabetical--;
			if(indexAlphabetical < 0){
				indexAlphabetical = dirDataSize + indexAlphabetical;
			}
			videoPlayerNewIndex = indexAlphabetical - videoPlayersIndex - 1;
			if(videoPlayerNewIndex < 0){
				videoPlayerNewIndex = dirDataSize + videoPlayerNewIndex;
			}
			videoPlayerNew = videoPlayers[last];
		}
		if(videoPlayerNewIndex >= 0){
			videoPlayerNew.load(indexesData[indexesAlphabetical[videoPlayerNewIndex]]);
		}
	}

	// check players.
	int indexNew = videoPlayersIndex;
	if(direction == "next"){
		indexNew++;
		if(indexNew >= (int)videoPlayers.size()){
			indexNew = indexNew - (int)videoPlayers.size();
		}
	}else if(direction == "previous"){
		indexNew--;
		if(indexNew < 0){
			indexNew = (int)videoPlayers.size() + indexNew;
		}
	}
	if(indexNew < 0 || indexNew >= (int)videoPlayers.size()){
		videoPlayerNew.close();
		return;
	}
	if(!videoPlayers[indexNew].isLoaded()){
		videoPlayerNew.close();
		loadVideoPlayers();
		return;
	}else if(indexNew != videoPlayersIndex){
		#ifdef TARGET_RASPBERRY_PI
			ofLogNotice("ofApp::triggerVideo", "Skipping play()...");
		#else
			// start new player.
			if(videoPlayers[indexNew].isPaused()){
				videoPlayers[indexNew].setPaused(false);
			}
			if(!videoPlayers[indexNew].isPlaying()){
				videoPlayers[indexNew].play();
			}
		#endif
	}

	// stop old video? replace videos at the start/end.
	if(videoPlayerNewIndex >= 0){
		videoPlayers[videoPlayersIndex].setPaused(true);
		if(direction == "next"){
			videoPlayers.erase(videoPlayers.begin());
			videoPlayers.push_back(videoPlayerNew);
		}else if(direction == "previous"){
			videoPlayers.erase(videoPlayers.end() - 1);
			videoPlayers.insert(videoPlayers.begin(), videoPlayerNew);
		}
	}

	// start video.
	if(videoPlayers[videoPlayersIndex].isLoaded()){
		setVideoSize();
		if(videoPlayers[videoPlayersIndex].isPaused()){
			videoPlayers[videoPlayersIndex].setPaused(false);
		}
		if(!videoPlayers[videoPlayersIndex].isPlaying()){
			videoPlayers[videoPlayersIndex].play();
		}
	}
}

void ofApp::bpmStart(){
	float bpmFramesFloat = (60.0f / bpm) / (1.0f / float(frameRate));
	bpmFrames = static_cast<int>(std::round(bpmFramesFloat));
}

void ofApp::bpmReset(){
	bpmFramesCounter = 0;
}

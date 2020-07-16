const functions = require('firebase-functions');
const _ = require('lodash');

const request = require('request-promise');

const admin = require('firebase-admin');
const ffmpegLib = require('fluent-ffmpeg');
const ffmpeg_static = require('ffmpeg-static');
ffmpegLib.setFfmpegPath(ffmpeg_static.path);
const fs = require('fs');
const os = require('os');
const path = require('path');

admin.initializeApp(functions.config().firebase);

const db = admin.firestore();


exports.indexUsersToElastic = functions.firestore.document('/users/{uid}').onWrite((change, context) => {
	let userData = change.after.data();
	let userId = context.params.uid;
	
	let followerCount = 0
	if(userData.followers !== undefined) {
		let followers = userData['followers'];
		followerCount = Object.keys(followers).length;
	}
	
	let postCount = 0;
	if(userData.posts !== undefined) {
		let posts = userData['posts'];
		postCount = Object.keys(posts).length;
	}

	console.log('Indexing user: ', userId, userData);
	
	let elasticSearchConfig = functions.config().elasticsearch;
	let elasticSearchUrl = elasticSearchConfig.url + '/users/_doc/' + userId;
	let elasticSearchMethod = userData ? 'POST' : 'DELETE';
	
	let elasticSearchRequest = {
		method: elasticSearchMethod,
		uri: elasticSearchUrl,
		auth: {
			username: elasticSearchConfig.username,
			password: elasticSearchConfig.password,
		},
		body: {
			"uid": userId,
			"username": userData['username'],
			"followerCount": followerCount,
			"postCount": postCount,
		},
		json: true
	};
	return request(elasticSearchRequest).then(response => {
		console.log('ElasticSearch Response: ', response);
		return;
	});
});

exports.usernameFanOut = functions.firestore.document('/users/{uid}').onWrite(async (change, context) => {
	let userDataAfter = change.after.data();
	let userDataBefore = change.before.data();
	let usernameAfter = userDataAfter['username'];
	let usernameBefore = userDataBefore['username'];
	let userId = userDataAfter['uid'];
	
	if(usernameAfter !== usernameBefore) {
		//Update username on all post documents from user
		await db.collection('posts').where('userUID', '==', userId).get().then(snapshot => {
			if(snapshot.empty) {
				console.log('User has no posts');
				return;
			}
			
			snapshot.forEach(doc => {
				let transaction = db.runTransaction(t => {
					return t.get(doc.ref).then(_doc => {
						t.update(_doc.ref, {username: usernameAfter});
						return;
					});
				});
			});
			return;
		}).catch(err => {
			console.log('Error getting user posts: ' + err);
		});
		
		//Update username on all direct posts where sender
		await db.collection('directposts').where('senderUID', '==', userId).get().then(snapshot => {
			if(snapshot.empty) {
				console.log('User has no direct posts');
				return;
			}
			
			snapshot.forEach(doc => {
				let transaction = db.runTransaction(t => {
					return t.get(doc.ref).then(_doc => {
						t.update(_doc.ref, {senderUsername: usernameAfter});
						return;
					});
				});
			});
			return;
		}).catch(err => {
			console.log('Error getting direct user posts: ' + err);
		});
		
		//Update username on all conversations user is included
		await db.collection('conversations').where('memberList', 'array-contains', userId).get().then(snapshot => {
			if(snapshot.empty) {
				console.log('User has no conversations');
				return;
			}
			
			snapshot.forEach(doc => {
				let transaction = db.runTransaction(t => {
					return t.get(doc.ref).then(_doc => {
						let docData = _doc.data();
						let conversationMembers = docData['conversationMembers'];
						conversationMembers[userId]['username'] = usernameAfter;
						t.update(_doc.ref, {conversationMembers: conversationMembers});
						return;
					});
				});
			});
			return;
		}).catch(err => {
			console.log('Error getting user posts: ' + err);
		});
	}
	return 1;
});

exports.directMessageNotification = functions.firestore.document('/conversations/{id}').onWrite((change, context) => {
	let beforeConversationData = change.before.data();
	let beforeLastDate = null;
	if(typeof beforeConversationData !== 'undefined')
		beforeLastDate = beforeConversationData['lastDate'];
	let conversationData = change.after.data();
	let lastDate = null;
	if(typeof conversationData !== 'undefined')
		lastDate = conversationData['lastDate'];
	let conversationMembers = conversationData['conversationMembers'];
	let conversationId = change.after.id;
	let senderUsername = 'A User'; 
	
	//console.log('Previous Last Date: ' + beforeLastDate.toDate().toString() + '; Current Last Date: ' + lastDate.toDate().toString());
	if(lastDate.isEqual(beforeLastDate)) {
		console.log('Should not send notification');
		return;
	}
	
	if(conversationData['lastPostUsername'] !== null)
		senderUsername = conversationData['lastPostUsername'];
	
	Object.keys(conversationMembers).forEach(key => {
		console.log('Key: ' + key);
		if(key !== conversationData['lastPostUserId']) {
			console.log('Username: ' + conversationMembers[key]['username']);
			return db.collection('users').doc(key).collection('tokens').get().then(querySnapshot => {
			if(querySnapshot.empty) {
				console.log('User ' + key + ' does not have messaging token');
			} else {
				querySnapshot.forEach(doc => {
					let token = doc.data().token;
					const payload = {
						notification: {
						title: `Perkl Message`,
						body: 'You have a new message on Perkl from ' + senderUsername + '!',
						badge: '1',
						sound: 'default',
						click_action:'FLUTTER_NOTIFICATION_CLICK',
						},
						data: {
							conversationId: conversationId,
							senderUsername: senderUsername,
						}
					}
					admin
						.messaging()
						.sendToDevice(token, payload)
						.then(response => {
						  console.log('Successfully sent message:', response);
						  return;
						})
						.catch(error => {
						  console.log('Error sending message:', error);
						});
				});
			}
			return 1;
		});
		}
	});
});

exports.getSearchResults = functions.firestore.document('/requests/{id}').onWrite((change, context) => {
	let requestData = change.after.data();
	let requestId = context.params.id;
	let searchTerm = requestData['searchTerm'];

	console.log('Searching...: ', searchTerm, requestData);
	
	let elasticSearchConfig = functions.config().elasticsearch;
	let elasticSearchUrl = elasticSearchConfig.url + '/users/_search';
	let elasticSearchMethod = 'GET';
	
	let elasticSearchRequest = {
		method: elasticSearchMethod,
		uri: elasticSearchUrl,
		auth: {
			username: elasticSearchConfig.username,
			password: elasticSearchConfig.password,
		},
		body: {
			"query": {
				"wildcard": {
					"username": {
						"value": "*" + searchTerm + "*"
					}
				}
			},
			"sort": [{"followerCount": {"order": "desc"}}]
		},
		json: true
	};
	
	
	
	return request(elasticSearchRequest).then(response => {
		let resultIDs = [];
		for(let i = 0; i < response.hits.hits.length; i++){
			result = response.hits.hits[i];
			resultIDs.push(result['_id']);
		}
		console.log('ElasticSearch Response: ', response['hits']['hits']);
		return change.after.ref.set({
			"results": resultIDs
		}, {merge: true});
	});
});

/*
exports.convertAudioFileFormatPosts = functions.firestore.document('/posts/{id}').onWrite(async (change, context) => {
	let convert = false;
	let requestData = change.after.data();
	console.log('Post Being Processed: ' + change.after.id);
	console.log('Post File URL: ' + requestData['audioFileLocation']);
	let fileUrl = requestData['audioFileLocation'];
	let userId = requestData['userUID'];
	let dateString = requestData['dateString'];
	let filePath = userId + '/' + dateString.replace(' ', '_');
	//set bucket for user to download audio file
	let bucket = admin.storage().bucket('flutter-fire-test-be63e.appspot.com');
	//define temporary file path to store file to for processing and output
	let tempFilePath = path.join(os.tmpdir(), "tempFile");
	let tempNewFilePath = path.join(os.tmpdir(), 'aac_tempFile');
	//start downloading the file to the temp path
	await bucket.file(filePath).download({destination: tempFilePath});
	//check if file needs to be processed
	await ffmpegLib
	    //.setFfmpegPath(ffmpeg_static.path)
	    .ffprobe(tempFilePath, function(err, metadata) {
	    console.log('probing file');
        if(!err) {
            let streams = metadata.streams;
            let data = streams[0];
            let formatData = metadata.format;
            let format = formatData.format_name
            //console.log('Input File Data: Streams ' + streams + '/Data ' + data + '/formatData ' + formatData + '/format ' + format);
            console.dir(metadata);
            if(format !== 'aac') {
                convert = true;
                console.log('should convert file');
            }
        } else {
            console.log('Error probing file: ' + err.message);
        }
    });
    console.log('Downloaded and probed file: ' + tempFilePath);
    //process file
    if(!convert) {
        let convertCommand = ffmpegLib({source: tempFilePath})
           //.setFfmpegPath(ffmpeg_static.path)
            .audioCodec('aac')
            .on('error', function(err) {
                console.log('Error Converting File: ' + err.message);
            }).saveToFile(tempNewFilePath);
        await bucket.upload(tempNewFilePath, {destination: dateString}).then((data) => {
            var file = data[0];
            console.log('File Uploaded: ' + file.getSignedUrl());
            return 0;
        });
    } else {
        console.log('Not converting file, already proper format');
    }
});
*/
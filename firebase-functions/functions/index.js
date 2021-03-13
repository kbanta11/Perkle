const functions = require('firebase-functions');
const _ = require('lodash');

const request = require('request-promise');

const admin = require('firebase-admin');
const firebase_tools = require('firebase-tools');
let serviceAccount = require('./flutter-fire-test-be63e-firebase-adminsdk-vlm6z-ad7f260341.json');
//const ffmpegLib = require('fluent-ffmpeg');
//const ffmpeg_static = require('ffmpeg-static');
//ffmpegLib.setFfmpegPath(ffmpeg_static.path);
const fs = require('fs');
const os = require('os');
const path = require('path');
let Parser = require('rss-parser');
const got = require('got');

admin.initializeApp(functions.config().firebase);

const db = admin.firestore();
db.settings({
  ignoreUndefinedProperties: true,
});


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
	let elasticSearchMethod = 'POST'; 
	if(!userId) {
		console.log('Deleting User from ElasticSearch due to empty user data: ' + userData);
		elasticSearchMethod = 'DELETE';
	};
	
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
		let postUpdatePromises = [];
		await db.collection('posts').where('userUID', '==', userId).get().then(snapshot => {
			if(snapshot.empty) {
				console.log('User has no posts');
				return;
			}
			
			snapshot.forEach(doc => {
				postUpdatePromises.push(db.runTransaction(t => {
					return t.get(doc.ref).then(_doc => {
						t.update(_doc.ref, {username: usernameAfter});
						return;
					});
				}));
			});
			return;
		}).catch(err => {
			console.log('Error getting user posts: ' + err);
		});
		await Promise.all(postUpdatePromises);
		
		//Update username on all direct posts where sender
		let directPostPromises = [];
		await db.collection('directposts').where('senderUID', '==', userId).get().then(snapshot => {
			if(snapshot.empty) {
				console.log('User has no direct posts');
				return;
			}
			
			snapshot.forEach(doc => {
				directPostPromises.push(db.runTransaction(t => {
					return t.get(doc.ref).then(_doc => {
						t.update(_doc.ref, {senderUsername: usernameAfter});
						return;
					});
				}));
			});
			return;
		}).catch(err => {
			console.log('Error getting direct user posts: ' + err);
		});
		await Promise.all(directPostPromises);
		
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

		//Update username on all podcast episode replies from sender
        await db.collection('episode-replies').where('posting_uid', '==', userId).get().then(snapshot => {
            if(snapshot.empty) {
                console.log('User has no podcast replies');
                return;
            }

            snapshot.forEach(doc => {
                let transaction = db.runTransaction(t => {
                    return t.get(doc.ref).then(_doc => {
                        t.update(_doc.ref, {posting_username: usernameAfter});
                        return;
                    });
                });
            });
            return;
        }).catch(err => {
            console.log('Error getting direct user posts: ' + err);
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
		//console.log('Key: ' + key);
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

exports.getTimeline = functions.runWith({timeoutSeconds: 300, memory: '1GB'}).https.onCall(async (data, context) => {
	let parser = new Parser();
	//let podFeeds = ['http://joeroganexp.joerogan.libsynpro.com/rss', 'https://rss.art19.com/bunga-bunga'];

	let allPostList = [];

	let timelineRef;
	let timelineId = data.timelineId;
	let timelineLastMinDate = null;
	//let timelineData = change.after.data();
	let timelineData = await db.collection('timelines').doc(timelineId).get().then(snapshot => {
		timelineRef = snapshot.ref;
		return snapshot.data();
	});

	if(timelineData.last_min_date){
		timelineLastMinDate = timelineData.last_min_date.toDate();
	} else if(data.reload) {
	  await firebase_tools.firestore.delete('/timelines/' + timelineId + '/items', {
        project: process.env.GCLOUD_PROJECT,
        recursive: true,
        yes: true,
        token: serviceAccount.token
      });
	}

	let podFeeds = timelineData.podcasts_included;
	//console.log(timelineData);
	let feedPromises = [];
	for(const i in podFeeds) {
		let url = podFeeds[i];
		url = url.replace('https:', 'http:');
		//console.log(url);
		let feed = parser.parseURL(url).then(f => {
			f.url = url;
			return f;
		});
		feedPromises.push(feed);
	}

	await Promise.all(feedPromises).then(feeds => {
		//console.log('Feed Length: ' + feeds.length);
		for(f in feeds) {
			let feed = feeds[f];
			//console.log('Feed Tuple: ' + feedTuple);
			//console.log('Current Feed: ' + feed.title + '/URL: ' + feed.feedUrl + '/Feed URL: ' + feedTuple[0]);
			let podcastData = {
				'podcast_feed': feed.feedUrl ? feed.feedUrl : feed.url,
				'image_url': feed.image.url,
				'podcast_title': feed.title,
				'podcast_description': feed.description,
			};
			console.log('----------------------------------------------------------------------------');
			for(const i in feed.items) {
				let item = feed.items[i]; 
				//console.log(item);
				let date = typeof item.pubDate !== "undefined" ? new Date(item.pubDate) : null;
				if(item.enclosure) {
					let episodeData = {
						'type': 'PODCAST_EPISODE',
						'podcast_feed': podcastData.podcast_feed,
						'image_url': typeof podcastData.image_url !== "undefined" ? podcastData.image_url : null,
						'podcast_title': podcastData.podcast_title,
						'podcast_description': typeof podcastData.podcast_description !== "undefined" ? podcastData.podcast_description : null,
						'title': item.title,
						'audio_url': item.enclosure.url,
						'bytes_length': item.enclosure.length,
						'description': item.content,
						'date_iso': item.isoDate,
						'date': date,
						'episode_guid': typeof item.guid !== "undefined" ? item.guid : null,
						'itunes_duration': typeof item.itunes.duration !== "undefined" ? item.itunes.duration : null,
						'episode': typeof item.itunes.episode !== "undefined" ? item.itunes.episode : null
					};
					//console.log(episodeData);
					allPostList.push(episodeData);
					//console.log(item.title + ': ' + item.enclosure.url + '/' + item.enclosure.length);
				}
			}
		}
		return;
	});

	await db.collection('posts').where('timelines', 'array-contains', timelineId).get().then(snapshot => {
		snapshot.forEach(doc => {
			let data = doc.data();
			postData = {
				'type': 'POST',
				'post_id': doc.ref.id,
				'title': typeof data.postTitle !== "undefined" ? data.postTitle : null,
				'audio_url': data.audioFileLocation,
				'seconds_length': typeof data.secondsLength !== "undefined" ? data.secondsLength : null,
				'ms_length': typeof data.ms_length !== "undefined" ? data.ms_length : null,
				'date': data.datePosted.toDate(),
				'userUID': data.userUID,
				'username':  data.username,
				'listenCount': data.listenCount,
				'streamList': typeof data.streamList !== "undefined" ? data.streamList : null,
			};
			//console.log(postData);
			allPostList.push(postData);
		});
		return;
	});
	allPostList.sort((a, b) => b.date - a.date);
	if(allPostList.length > 50) {
		if(timelineLastMinDate === null) {
			allPostList = allPostList.slice(0, 50);
		} else {
			let currentPostList = allPostList.filter(p => p.date >= timelineLastMinDate);
			let remainingPosts = allPostList.filter(p => p.date < timelineLastMinDate);
			allPostList = remainingPosts.slice(0, 50);
		}
	}
	let current_audio_urls = await timelineRef.collection('items').get().then(querySnapshot => {
		if(!querySnapshot.empty) {
			return querySnapshot.docs.map(doc => {
				return doc.data().audio_url
			});
		}
		return;
	});
	//console.log(current_audio_urls);
	let batch = db.batch();
	for(const p in allPostList) {
		let post = allPostList[p];
		if(current_audio_urls){
			if(!current_audio_urls.includes(post.audio_url)) {
				batch.set(timelineRef.collection('items').doc(encodeURIComponent(post.audio_url)), post);
			}
		} else {
			batch.set(timelineRef.collection('items').doc(encodeURIComponent(post.audio_url)), post);
		}
	}
	await batch.commit();
	console.log('Total Posts: ' + allPostList.length);
	
	console.log('complete');
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
			"sort": [{"followerCount": {"order": "desc"}}],
			"size": 50,
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

exports.updateTopUsers = functions.pubsub.schedule('every 30 minutes').onRun( async (context) => {
    await db.collection('requests').doc('discover').get().then(snapshot => {
        db.runTransaction(t => {
            return t.get(snapshot.ref).then(doc => {
                t.update(snapshot.ref, {searchDate: new Date()});
                return;
            });
        });
        return;
    }).catch(err => {
        console.log('Error getting updated users: ' + err);
    });
});

exports.updateTopPodcasts = functions.pubsub.schedule('30 4 * * *').onRun(async (context) => {
	let genre_docs = []
	await db.collection('top-podcasts').get().then(snapshot => {
		snapshot.forEach(doc => {
			let data = doc.data();
			let genre_ref = doc.ref;
			data.ref = genre_ref;
			genre_docs.push(data);
		});
		return;
	});

	let genre_results = [];
	let genre_updates = [];
	for(g in genre_docs) {
		let genre_data = genre_docs[g];
		//Set URL for current genre document
		let url = 'https://itunes.apple.com/us/rss/toppodcasts/limit=100/explicit=true/json';
		if(genre_data.genre_id) {
			url = 'https://itunes.apple.com/us/rss/toppodcasts/limit=100/genre=' + genre_data.genre_id + '/explicit=true/json';
		}

		genre_updates.push(db.runTransaction(t => {
			t.update(genre_data.ref, {'last_updated': new Date(Date.now())});
			return Promise.resolve();
		}));

		//Get top podcast results
		let genre_result_promise = got(url, {json: true, allowGetBody: true}).then(result => {
			//console.log(result.body);
			result.body['genre_data'] = {'genre_title': genre_data.title, 'genre_id': genre_data.genre_id, 'doc_name': genre_data.doc_name};
			//console.log(result.body.feed.genre_data);
			//console.log(result.body);
			return result;
		});
		genre_results.push(genre_result_promise);
	}

	let ranked_pods = [];
	await Promise.all(genre_results).then(async results => {
		for(r in results) {
			//console.log(r);
			let result = results[r];
			let feed_data = result.body;
			console.log(feed_data.genre_data);
			let entries = feed_data.entry;
			for(e in entries) {
				let entry = entries[e];
				let rank = e;
				let id = entry['id']['attributes']['im:id'];
				//console.log(entry);
				ranked_pods.push({
					'rank': rank,
					'genre_id': feed_data.genre_data.genre_id,
					'genre_title': feed_data.genre_data.genre_title,
					'genre_doc_name': feed_data.genre_data.doc_name,
					'itunes_id': id
				});
			}
		}
		return;
	});

	let top_podcast_read_promises = [];
	/* eslint-disable no-await-in-loop */
	for(x in ranked_pods) {
		rp = ranked_pods[x];
		try {
			await sleep(3000);
			console.log(rp.itunes_id + ': ' + rp.genre_title + '/' + rp.genre_doc_name);
			let pod_data_read_promise = await got('https://itunes.apple.com/lookup?id=' + rp.itunes_id, {json: true, allowGetBody: true}).then(result => {
					let data = result.body.results[0];
					let pod_data = {
						'rank': rp.rank,
						'genre_id': rp.genre_id,
						'genre_title': rp.genre_title,
						'genre_doc_name': rp.genre_doc_name,
						'podcast_title': data.collectionName,
						'feed_url': data.feedUrl,
						'itunes_id': rp.itunes_id,
						'artwork_url_30': data.artworkUrl30,
						'artwork_url_60': data.artworkUrl60,
						'artwork_url_100': data.artworkUrl100,
					}
					//console.log(pod_data);
					return pod_data;
				}).catch((e) => console.log('Error getting podcast data: ' + e));
			top_podcast_read_promises.push(pod_data_read_promise);
		} catch (e) {
			console.log('Error: ' + e);
		}
	}

	let batches = [];
	await Promise.all(top_podcast_read_promises).then(results => {
		let batch = db.batch();
		let i = 0;
		for(r in results) {
			console.log(i);
			let pod = results[r];
			let ref = db.collection('top-podcasts').doc(pod.genre_doc_name).collection('podcasts').doc(encodeURIComponent(pod.feed_url));
			batch.set(ref, pod);
			if(i === 499) {
				batches.push(batch);
				batch = db.batch();
				i = 0;
			} else {
				i = i + 1;
			}

		}
		return;
	});
	console.log('Number of batches: ' + batches.length);
	for(g in genre_docs) {
		let data = genre_docs[g];
		//Add promise for deleting all current values in each genre
		await firebase_tools.firestore.delete('/top-podcasts/' + data.doc_name + '/podcasts', {
	        project: process.env.GCLOUD_PROJECT,
	        recursive: true,
	        yes: true,
	        token: serviceAccount.token
	      });
	}
	await Promise.all(genre_updates);
	for(b in batches) {
		let bat = batches[b];
		bat.commit();
	}
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
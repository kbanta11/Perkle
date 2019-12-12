const functions = require('firebase-functions');
const _ = require('lodash');

const request = require('request-promise');

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
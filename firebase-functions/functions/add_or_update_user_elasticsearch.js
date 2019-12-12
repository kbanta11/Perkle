
const functions = require('firebase-functions');
const _ = require('lodash');

const request = require('request-promise');

exports.indexUsersToElastic = functions.database.ref('/users/{uid}').onWrite(event => {
	let userData = event.data.val();
	let userId = event.params.uid;
	
	console.log('Indexing user: ', userId, userData);
	print(userData);
});

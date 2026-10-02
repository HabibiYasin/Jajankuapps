// Admin only. Uses Application Default Credentials; never bundle with Flutter.
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
initializeApp({credential: applicationDefault(), projectId: 'jajanku-26976'});
const users = getFirestore().collection('users');
Promise.all([
  users.count().get(),
  users.where('plan', '==', 'free').count().get(),
  users.where('plan', '==', 'vip').count().get(),
]).then(([total, free, vip]) => {
  console.table({total: total.data().count, free: free.data().count, vip: vip.data().count});
}).catch(error => {console.error(error.message); process.exitCode = 1;});

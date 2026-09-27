importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: 'AIzaSyBAhSsjXViz0AMYFKipbU-dsSGDuBtKS44',
  appId: '1:1077407633101:web:e3fe7a12b7068ae5b1e384',
  messagingSenderId: '1077407633101',
  projectId: 'novel-mn',
  authDomain: 'novel-mn.firebaseapp.com',
  storageBucket: 'novel-mn.firebasestorage.app',
  measurementId: 'G-0S22EDBQ3C',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log(
    '[firebase-messaging-sw.js] Background message:',
    payload,
  );
});

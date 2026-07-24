const form = document.getElementById('loginForm');
const errorBox = document.getElementById('loginError');
const button = document.getElementById('loginButton');
const config = window.MATCHU_FIREBASE_CONFIG || {};
let auth = null;
let setupError = null;

function showError(message) {
  errorBox.textContent = message;
  errorBox.classList.remove('d-none');
}

function setLoading(loading) {
  button.disabled = loading;
  button.querySelector('.button-label').textContent = loading ? 'Đang đăng nhập...' : 'Đăng nhập';
  button.querySelector('.spinner-border').classList.toggle('d-none', !loading);
}

function firebaseMessage(code) {
  const messages = {
    'auth/invalid-credential': 'Email hoặc mật khẩu không chính xác.',
    'auth/user-not-found': 'Email hoặc mật khẩu không chính xác.',
    'auth/wrong-password': 'Email hoặc mật khẩu không chính xác.',
    'auth/user-disabled': 'Tài khoản này đã bị vô hiệu hóa.',
    'auth/too-many-requests': 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.',
    'auth/network-request-failed': 'Không thể kết nối mạng. Vui lòng kiểm tra kết nối của bạn.',
    'auth/invalid-api-key': 'Firebase Web API Key chưa hợp lệ.',
    'auth/unauthorized-domain': 'Tên miền hiện tại chưa được thêm vào Firebase Authentication > Authorized domains.',
    'auth/operation-not-allowed': 'Email/Password chưa được bật trong Firebase Authentication.',
    'auth/invalid-email': 'Địa chỉ email không hợp lệ.'
  };
  return messages[code] || 'Đăng nhập không thành công. Vui lòng thử lại.';
}

document.getElementById('togglePassword')?.addEventListener('click', () => {
  const input = document.getElementById('password');
  const icon = document.querySelector('#togglePassword i');
  input.type = input.type === 'password' ? 'text' : 'password';
  icon.className = input.type === 'password' ? 'bi bi-eye' : 'bi bi-eye-slash';
});

// Dynamic imports are intentionally caught so a CDN/CSP/configuration problem cannot
// fall through to the browser's default form submit (which looks like a page reload).
try {
  if (!config.apiKey || !config.authDomain || !config.projectId) {
    throw new Error('missing-firebase-web-config');
  }
  const [{ initializeApp }, { getAuth, signInWithEmailAndPassword, signOut }] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js')
  ]);
  // appId is optional for Firebase Authentication. Ignore an Android/iOS app ID
  // here; analytics is not initialized on the admin login page.
  const webConfig = { apiKey: config.apiKey, authDomain: config.authDomain, projectId: config.projectId };
  if (/^1:\d+:web:[a-zA-Z0-9]+$/.test(config.appId || '')) webConfig.appId = config.appId;
  auth = getAuth(initializeApp(webConfig));
  window.matchuFirebaseSignIn = signInWithEmailAndPassword;
  window.matchuFirebaseSignOut = signOut;
} catch (error) {
  setupError = error;
  // Only a non-sensitive error code is sent to the browser console for diagnostics.
  console.error('Firebase login setup failed:', error?.code || error?.message || 'unknown');
}

form?.addEventListener('submit', async (event) => {
  event.preventDefault();
  errorBox.classList.add('d-none');

  if (setupError || !auth) {
    const message = setupError?.message === 'missing-firebase-web-config'
      ? 'Firebase Web SDK chưa được cấu hình đầy đủ trên máy chủ.'
      : 'Không thể khởi tạo Firebase đăng nhập. Hãy kiểm tra Console trình duyệt và cấu hình Authorized domains.';
    showError(message);
    return;
  }

  setLoading(true);
  try {
    const credential = await window.matchuFirebaseSignIn(auth, document.getElementById('email').value.trim(), document.getElementById('password').value);
    const idToken = await credential.user.getIdToken();
    const response = await fetch('/auth/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ idToken, rememberMe: document.getElementById('rememberMe').checked })
    });
    const result = await response.json();
    if (!response.ok || !result.success) throw { serverMessage: result.message };
    await window.matchuFirebaseSignOut(auth);
    window.location.assign(result.redirectUrl || '/dashboard');
  } catch (error) {
    showError(error.serverMessage || firebaseMessage(error.code));
    setLoading(false);
  }
});

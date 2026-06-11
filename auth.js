async function initAuth() {
    try {
        // 1. Get the current session from Supabase local storage
        const { data: { session }, error } = await saudiaClient.auth.getSession();

        if (error) throw error;

        if (session && session.user) {
            // 2. User is already logged in, set them as active
            activeUser = session.user;
            
            // 3. Load the application data immediately
            await loadApp(); 
            
            console.log("Session restored successfully.");
        } else {
            // 4. No session found, stay on the login screen
            document.getElementById('login-screen').style.display = 'flex';
            document.getElementById('main-app').style.display = 'none';
        }
    } catch (err) {
        console.error("Auth initialization failed:", err.message);
        // Fallback to login screen if something goes wrong
        document.getElementById('login-screen').style.display = 'flex';
    }
}

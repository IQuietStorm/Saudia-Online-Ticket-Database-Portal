let authMode = 'login';
let activeUser = null;
let currentUserRole = 'user';
let accountDropdownOpen = false;
let selectedTicketId = null;
let currentPage = 1;
const PAGE_SIZE = 10;
const STORAGE_TICKETS_KEY = 'saudia_ticket_database';
const STORAGE_USERS_KEY = 'saudia_user_database';
let tickets = [];
let users = [];
let archivedPage = 1;

function setLoginMode() {
    const signupFields = document.getElementById('signup-fields');
    const authTitle = document.getElementById('auth-title');
    const authBtn = document.getElementById('main-auth-btn');
    const toggleText = document.getElementById('toggle-text');
    const lblPassword = document.getElementById('lbl-password');

    if (!signupFields || !authTitle || !authBtn || !toggleText || !lblPassword) return;

    signupFields.style.display = authMode === 'signup' ? 'block' : 'none';
    authTitle.textContent = authMode === 'signup' ? 'Create Your Saudia Cloud TMS Account' : 'Cloud TMS Login';
    authBtn.textContent = authMode === 'signup' ? 'Sign Up' : 'Sign In';
    toggleText.textContent = authMode === 'signup' ? 'Already have an account? Sign In' : 'Need an account? Sign Up';
    lblPassword.textContent = authMode === 'signup' ? 'Choose a Password' : 'Security Password';
}

function toggleAuthMode() {
    authMode = authMode === 'login' ? 'signup' : 'login';
    setLoginMode();
}

function getLocalUserRole(email) {
    if (!email) return 'user';
    const found = users.find((user) => user.email?.toLowerCase() === email.toLowerCase());
    if (!found) return 'user';
    
    // Check for temporary supervisor role expiration
    if (found.role === 'supervisor' && found.tempSupervisorEnd) {
        const endDate = new Date(found.tempSupervisorEnd);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        endDate.setHours(0, 0, 0, 0);
        
        if (today > endDate) {
            // Temporary role has expired, revert to user
            found.role = 'user';
            found.tempExpired = true;
            persistUsers();
            return 'user';
        }
    }
    
    return found?.role || 'user';
}

function formatRoleLabel(role) {
    return String(role || 'user').trim().toUpperCase();
}

function closeAccountDropdown() {
    const dropdown = document.getElementById('accountMenuDropdown');
    if (!dropdown) return;
    accountDropdownOpen = false;
    dropdown.style.display = 'none';
}

function updateThemeToggleButton() {
    const themeBtn = document.getElementById('theme-toggle');
    if (!themeBtn) return;
    const current = document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
    themeBtn.textContent = current === 'dark' ? 'Light Mode' : 'Night Mode';
}

function initializeTheme() {
    const saved = localStorage.getItem('tms_theme') || 'light';
    document.documentElement.dataset.theme = saved;
    updateThemeToggleButton();
}

async function handleAuth() {
    const emailInput = document.getElementById('email');
    const passwordInput = document.getElementById('password');

    if (!emailInput || !passwordInput) {
        return console.error('Login elements are missing from the page.');
    }

    const email = emailInput.value.trim();
    const password = passwordInput.value;

    if (!email || !password) {
        return alert('Please enter email and password.');
    }

    try {
        if (authMode === 'signup') {
            const { data, error } = await saudiaClient.auth.signUp({ email, password });
            if (error) throw error;
            alert('A confirmation email has been sent. Please verify your account and sign in.');
            authMode = 'login';
            setLoginMode();
            return;
        }

        const { data, error } = await saudiaClient.auth.signInWithPassword({ email, password });
        if (error) throw error;
        activeUser = data.user;
        await loadApp();
    } catch (err) {
        console.error('Authentication failed:', err.message || err);
        alert('Authentication failed. Please check your credentials and try again.');
    }
}

async function initAuth() {
    try {
        const { data: { session }, error } = await saudiaClient.auth.getSession();
        if (error) throw error;

        if (session && session.user) {
            activeUser = session.user;
            await loadApp();
            console.log('Session restored successfully.');
        } else {
            document.getElementById('login-screen').style.display = 'flex';
            document.getElementById('main-app').style.display = 'none';
            setLoginMode();
        }
    } catch (err) {
        console.error('Auth initialization failed:', err.message || err);
        document.getElementById('login-screen').style.display = 'flex';
        document.getElementById('main-app').style.display = 'none';
        setLoginMode();
    }
}

async function logout() {
    try {
        await saudiaClient.auth.signOut();
    } catch (err) {
        console.warn('Sign out encountered an issue:', err.message || err);
    }
    activeUser = null;
    document.getElementById('login-screen').style.display = 'flex';
    document.getElementById('main-app').style.display = 'none';
}

async function loadApp() {
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('main-app').style.display = 'block';
    const dropName = document.getElementById('drop-name');
    const dropRole = document.getElementById('drop-role');
    const avatarLetters = document.getElementById('avatar-letters');

    loadStoredData();
    currentUserRole = getLocalUserRole(activeUser?.email);

    if (activeUser) {
        const displayName = activeUser.email || 'Staff Member';
        if (dropName) dropName.textContent = displayName;
        if (dropRole) dropRole.textContent = formatRoleLabel(currentUserRole);
        if (avatarLetters) avatarLetters.textContent = displayName.slice(0, 2).toUpperCase();
    }

    const adminDashBtn = document.getElementById('admin-dash-btn');
    const accountMgmtItem = document.getElementById('account-mgmt-item');
    const canManage = currentUserRole === 'admin';
    if (adminDashBtn) {
        adminDashBtn.style.display = canManage ? 'inline-flex' : 'none';
    }
    if (accountMgmtItem) {
        accountMgmtItem.style.display = canManage ? 'block' : 'none';
    }

    setLoginMode();
    toggleDynamicFields();
    updateThemeToggleButton();
}

function loadStoredData() {
    tickets = JSON.parse(localStorage.getItem(STORAGE_TICKETS_KEY) || '[]');
    users = JSON.parse(localStorage.getItem(STORAGE_USERS_KEY) || '[]');
    renderUsersTable();
    renderTicketsTable();
    updateSelectAllExportCheckbox();
}

function persistTickets() {
    localStorage.setItem(STORAGE_TICKETS_KEY, JSON.stringify(tickets));
}

function persistUsers() {
    localStorage.setItem(STORAGE_USERS_KEY, JSON.stringify(users));
}

function toggleAdminDashboard() {
    const adminDash = document.getElementById('admin-dashboard');
    if (!adminDash) return;
    adminDash.style.display = adminDash.style.display === 'block' ? 'none' : 'block';
}

function toggleLanguage() {
    const current = document.documentElement.lang || 'en';
    const next = current === 'en' ? 'ar' : 'en';
    document.documentElement.lang = next;
    document.documentElement.dir = next === 'ar' ? 'rtl' : 'ltr';
    localStorage.setItem('tms_lang', next);
    // update button label
    const btn = document.getElementById('lang-btn');
    if (btn) btn.textContent = next === 'ar' ? 'EN' : 'العربية';
}

function initializeLanguage() {
    const saved = localStorage.getItem('tms_lang') || 'en';
    document.documentElement.lang = saved;
    document.documentElement.dir = saved === 'ar' ? 'rtl' : 'ltr';
    const btn = document.getElementById('lang-btn');
    if (btn) btn.textContent = saved === 'ar' ? 'EN' : 'العربية';
}

function toggleTheme() {
    const html = document.documentElement;
    const isDark = html.dataset.theme === 'dark';
    const nextTheme = isDark ? 'light' : 'dark';
    html.dataset.theme = nextTheme;
    localStorage.setItem('tms_theme', nextTheme);
    updateThemeToggleButton();
}

function toggleMobileLayout() {
    document.body.classList.toggle('mobile-layout');
}

function toggleAccountDropdown() {
    const dropdown = document.getElementById('accountMenuDropdown');
    if (!dropdown) return;
    accountDropdownOpen = !accountDropdownOpen;
    dropdown.style.display = accountDropdownOpen ? 'block' : 'none';
}

function createNewUser() {
    const nameField = document.getElementById('newUserName');
    const emailField = document.getElementById('newUserEmail');
    const passwordField = document.getElementById('newUserPassword');
    const roleField = document.getElementById('newUserRole');
    const tempStartField = document.getElementById('tempSupervisorStart');
    const tempEndField = document.getElementById('tempSupervisorEnd');

    if (!nameField || !emailField || !passwordField || !roleField) return;

    const name = nameField.value.trim();
    const email = emailField.value.trim();
    const password = passwordField.value;
    const role = roleField.value;
    const tempStart = tempStartField?.value || null;
    const tempEnd = tempEndField?.value || null;

    if (!name || !email || !password) {
        return alert('Please complete user name, email, and password.');
    }

    if (users.some((user) => user.email === email)) {
        return alert('A user with that email already exists.');
    }

    // Validate temporary role dates if supervisor role
    if (role === 'supervisor' && (tempStart || tempEnd)) {
        if (tempStart && tempEnd && tempStart > tempEnd) {
            return alert('Start date must be before end date.');
        }
    }

    const newUser = {
        id: crypto.randomUUID(),
        name,
        email,
        role,
        createdAt: new Date().toISOString(),
        tempSupervisorStart: tempStart || null,
        tempSupervisorEnd: tempEnd || null,
        isTemporary: role === 'supervisor' && !!tempEnd
    };

    users.push(newUser);
    persistUsers();
    renderUsersTable();
    nameField.value = '';
    emailField.value = '';
    passwordField.value = '';
    roleField.value = 'user';
    if (tempStartField) tempStartField.value = '';
    if (tempEndField) tempEndField.value = '';
    toggleTemporarySupervisorFields();
    alert('New user added to local user database.');
}

function validateTicketNumInput(input) {
    input.value = input.value.replace(/[^0-9]/g, '').slice(0, 13);
}

function checkDuplicateTicketLive() {
    const ticketNum = document.getElementById('ticketNum')?.value.trim();
    if (!ticketNum) {
        return hideDuplicateBanner();
    }

    const duplicate = tickets.some((ticket) => ticket.ticketNum === ticketNum && ticket.id !== selectedTicketId);

    if (duplicate) {
        showDuplicateBanner('This ticket number already exists in the database.');
    } else {
        hideDuplicateBanner();
    }
}

function showDuplicateBanner(message) {
    const banner = document.getElementById('duplicate-ticket-banner');
    if (banner) {
        banner.textContent = message;
        banner.style.display = 'block';
        banner.style.background = '#fef3c7';
        banner.style.color = '#92400e';
        banner.style.padding = '10px';
        banner.style.borderRadius = '6px';
        banner.style.marginBottom = '12px';
    }
}

function hideDuplicateBanner() {
    const banner = document.getElementById('duplicate-ticket-banner');
    if (banner) {
        banner.style.display = 'none';
        banner.textContent = '';
    }
}

function toggleDynamicFields() {
    const ticketType = document.getElementById('ticketType')?.value;
    const ticketStatus = document.getElementById('ticketStatus')?.value;
    const reissueSection = document.getElementById('reissue-section');
    const refundSection = document.getElementById('refund-section');
    const upgradeReasonDiv = document.getElementById('upgrade-reason-div');
    const downgradeReasonDiv = document.getElementById('downgrade-reason-div');
    const rebookReasonDiv = document.getElementById('rebook-reason-div');

    if (reissueSection) reissueSection.style.display = ticketType === 'Re-issue' ? 'block' : 'none';
    if (refundSection) refundSection.style.display = ticketStatus === 'Refunded' ? 'block' : 'none';
    if (upgradeReasonDiv) upgradeReasonDiv.style.display = ticketType === 'Re-issue' && document.getElementById('reissueReason')?.value === 'Upgrade' ? 'block' : 'none';
    if (downgradeReasonDiv) downgradeReasonDiv.style.display = ticketType === 'Re-issue' && document.getElementById('reissueReason')?.value === 'Downgrade' ? 'block' : 'none';
    if (rebookReasonDiv) rebookReasonDiv.style.display = ticketType === 'Re-issue' && document.getElementById('reissueReason')?.value === 'Rebook' ? 'block' : 'none';
}

function collectTicketForm() {
    const ticketNum = document.getElementById('ticketNum')?.value.trim();
    const ticketType = document.getElementById('ticketType')?.value;
    const ticketStatus = document.getElementById('ticketStatus')?.value;
    const issueDate = document.getElementById('issueDate')?.value;
    const issuerName = document.getElementById('issuerName')?.value.trim();
    const flightDate = document.getElementById('flightDate')?.value;
    const statusComment = document.getElementById('statusComment')?.value.trim();
    const reissueReason = document.getElementById('reissueReason')?.value;
    const upgradeReason = document.getElementById('upgradeReason')?.value;
    const downgradeReason = document.getElementById('downgradeReason')?.value;
    const rebookReason = document.getElementById('rebookReason')?.value;
    const refundRecipient = document.getElementById('refundRecipient')?.value.trim();

    return {
        ticketNum,
        ticketType,
        ticketStatus,
        issueDate,
        issuerName,
        flightDate,
        statusComment,
        reissueReason,
        upgradeReason,
        downgradeReason,
        rebookReason,
        refundRecipient,
        updatedAt: new Date().toISOString(),
    };
}

function validateTicketForm(form) {
    if (!form.ticketNum || form.ticketNum.length !== 13) {
        return 'Ticket number must be 13 digits.';
    }
    if (!form.issueDate) {
        return 'Issue date is required.';
    }
    if (!form.issuerName) {
        return 'Issuer name is required.';
    }
    if (!form.flightDate) {
        return 'Flight date is required.';
    }
    return '';
}

function saveTicket() {
    const ticket = collectTicketForm();
    const validationError = validateTicketForm(ticket);
    if (validationError) {
        return alert(validationError);
    }
    if (tickets.some((item) => item.ticketNum === ticket.ticketNum && item.id !== selectedTicketId)) {
        return alert('A ticket with this number already exists.');
    }

    const newTicket = {
        id: crypto.randomUUID(),
        ...ticket,
        createdBy: activeUser?.email || 'local-user',
        createdAt: new Date().toISOString(),
    };

    tickets.unshift(newTicket);
    persistTickets();
    clearFormFields();
    currentPage = 1;
    renderTicketsTable();
    alert('Ticket saved locally.');
}

function updateTicket() {
    if (!selectedTicketId) {
        return alert('Select a ticket row first to update it.');
    }

    const ticket = collectTicketForm();
    const validationError = validateTicketForm(ticket);
    if (validationError) {
        return alert(validationError);
    }
    if (tickets.some((item) => item.ticketNum === ticket.ticketNum && item.id !== selectedTicketId)) {
        return alert('Another ticket with this number already exists.');
    }

    tickets = tickets.map((item) => {
        if (item.id === selectedTicketId) {
            return { ...item, ...ticket };
        }
        return item;
    });
    persistTickets();
    renderTicketsTable();
    alert('Ticket updated successfully.');
}

function deleteTicket() {
    if (!selectedTicketId) {
        return alert('Select a ticket row to delete it.');
    }

    const role = (currentUserRole || getLocalUserRole(activeUser?.email) || '').toLowerCase();
    const willArchive = role === 'supervisor';
    const confirmMsg = willArchive ? 'Archive (soft-delete) selected ticket?' : 'Delete selected ticket permanently?';
    if (!confirm(confirmMsg)) {
        return;
    }
    const ticket = tickets.find((item) => item.id === selectedTicketId);
    if (!ticket) return alert('Selected ticket not found.');

    // Permission: admin and supervisor can delete any; users can delete only their own tickets
    const isOwner = ticket.createdBy && activeUser && ticket.createdBy.toLowerCase() === (activeUser.email || '').toLowerCase();
    const allowed = role === 'admin' || role === 'supervisor' || (role === 'user' && isOwner);
    if (!allowed) return alert('You do not have permission to delete this ticket.');

    if (role === 'supervisor') {
        // Soft-delete (archive)
        ticket.deleted = true;
        ticket.deletedAt = new Date().toISOString();
        ticket.deletedBy = activeUser?.email || 'supervisor';
        persistTickets();
        clearFormFields();
        renderTicketsTable();
        return alert('Ticket archived (soft-deleted).');
    }

    // Admin or owner user: permanent delete
    tickets = tickets.filter((item) => item.id !== selectedTicketId);
    persistTickets();
    clearFormFields();
    renderTicketsTable();
    alert('Ticket deleted.');
}

function clearFormFields() {
    selectedTicketId = null;
    const inputs = document.querySelectorAll('#tickets-container input, #tickets-container select');
    inputs.forEach((field) => {
        if (field.type === 'checkbox') {
            field.checked = false;
        } else {
            field.value = '';
        }
    });
    hideDuplicateBanner();
    hideSelectedTicketActions();
    closeInspectionPane();
    toggleDynamicFields();
}

function hideSelectedTicketActions() {
    const updateBtn = document.getElementById('admin-upd');
    const deleteBtn = document.getElementById('admin-del');
    if (updateBtn) updateBtn.style.display = 'none';
    if (deleteBtn) deleteBtn.style.display = 'none';
}

function renderTicketsTable() {
    const tableBody = document.getElementById('tableBody');
    const pageInfo = document.getElementById('paginationDisplay');
    if (!tableBody || !pageInfo) return;

    const filtered = getFilteredTickets();
    const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    if (currentPage > pages) currentPage = pages;
    if (currentPage < 1) currentPage = 1;
    const startIndex = (currentPage - 1) * PAGE_SIZE;
    const pageTickets = filtered.slice(startIndex, startIndex + PAGE_SIZE);

    tableBody.innerHTML = '';
    pageTickets.forEach((ticket) => {
        const row = document.createElement('tr');
        row.dataset.ticketId = ticket.id;
        row.style.cursor = 'pointer';

        const checkboxCell = document.createElement('td');
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.className = 'export-row-checkbox';
        checkbox.value = ticket.id;
        checkbox.addEventListener('click', (event) => event.stopPropagation());
        checkboxCell.appendChild(checkbox);
        row.appendChild(checkboxCell);

        const cells = [
            ticket.ticketNum,
            ticket.ticketType,
            ticket.ticketStatus,
            ticket.issueDate,
            ticket.issuerName,
            ticket.flightDate,
            ticket.statusComment,
            ticket.createdBy,
        ];

        cells.forEach((value) => {
            const cell = document.createElement('td');
            cell.textContent = value || '-';
            row.appendChild(cell);
        });

        row.addEventListener('click', () => selectTicketRow(ticket.id));
        tableBody.appendChild(row);
    });

    pageInfo.textContent = `Page ${currentPage} of ${pages}`;
    // render page selector
    pageInfo.innerHTML = `Page ${currentPage} of ${pages} <select id="pageSelect" onchange="goToPage(this.value)"></select>`;
    const sel = document.getElementById('pageSelect');
    if (sel) {
        for (let i = 1; i <= pages; i++) {
            const opt = document.createElement('option');
            opt.value = i;
            opt.text = i;
            if (i === currentPage) opt.selected = true;
            sel.appendChild(opt);
        }
    }
    updateSelectAllExportCheckbox();
}

function goToPage(page) {
    page = parseInt(page, 10) || 1;
    currentPage = page;
    renderTicketsTable();
}

function getFilteredTickets() {
    const searchValue = document.getElementById('filterSearch')?.value.trim().toLowerCase();
    const statusFilter = document.getElementById('filterStatus')?.value;
    const typeFilter = document.getElementById('filterType')?.value;
    const dateFrom = document.getElementById('filterDateFrom')?.value;
    const dateTo = document.getElementById('filterDateTo')?.value;

    return tickets.filter((ticket) => {
        // Exclude soft-deleted tickets from normal listings
        if (ticket.deleted) return false;
        if (statusFilter && statusFilter !== 'All' && ticket.ticketStatus !== statusFilter) {
            return false;
        }
        if (typeFilter && typeFilter !== 'All' && ticket.ticketType !== typeFilter) {
            return false;
        }
        if (dateFrom && ticket.issueDate < dateFrom) {
            return false;
        }
        if (dateTo && ticket.issueDate > dateTo) {
            return false;
        }
        if (searchValue) {
            const haystack = [
                ticket.ticketNum,
                ticket.ticketType,
                ticket.ticketStatus,
                ticket.issueDate,
                ticket.issuerName,
                ticket.flightDate,
                ticket.statusComment,
                ticket.createdBy,
            ].join(' ').toLowerCase();
            return haystack.includes(searchValue);
        }
        return true;
    });
}

function selectTicketRow(ticketId) {
    const ticket = tickets.find((item) => item.id === ticketId);
    if (!ticket) return;
    selectedTicketId = ticketId;
    populateTicketForm(ticket);
    showSelectedTicketActions();
    renderTicketPreview(ticket);
}

function populateTicketForm(ticket) {
    document.getElementById('ticketNum').value = ticket.ticketNum || '';
    document.getElementById('ticketType').value = ticket.ticketType || 'Fresh Issue';
    document.getElementById('ticketStatus').value = ticket.ticketStatus || 'Flown';
    document.getElementById('issueDate').value = ticket.issueDate || '';
    document.getElementById('issuerName').value = ticket.issuerName || '';
    document.getElementById('flightDate').value = ticket.flightDate || '';
    document.getElementById('statusComment').value = ticket.statusComment || '';
    document.getElementById('reissueReason').value = ticket.reissueReason || 'Upgrade';
    document.getElementById('upgradeReason').value = ticket.upgradeReason || 'Ffp Gold Tier';
    document.getElementById('downgradeReason').value = ticket.downgradeReason || 'Aircraft Change';
    document.getElementById('rebookReason').value = ticket.rebookReason || 'Flight Delay / Connection Missed';
    document.getElementById('refundRecipient').value = ticket.refundRecipient || '';
    toggleDynamicFields();
}

function showSelectedTicketActions() {
    const updateBtn = document.getElementById('admin-upd');
    const deleteBtn = document.getElementById('admin-del');
    if (updateBtn) updateBtn.style.display = 'inline-flex';
    if (deleteBtn) deleteBtn.style.display = 'inline-flex';
}

function renderTicketPreview(ticket) {
    const previewPane = document.getElementById('sidePreviewPane');
    const previewContent = document.getElementById('previewPaneContent');
    if (!previewPane || !previewContent) return;

    previewContent.innerHTML = `
        <div style="line-height:1.6;">
            <p><strong>Ticket Number:</strong> ${ticket.ticketNum}</p>
            <p><strong>Type:</strong> ${ticket.ticketType}</p>
            <p><strong>Status:</strong> ${ticket.ticketStatus}</p>
            <p><strong>Issue Date:</strong> ${ticket.issueDate}</p>
            <p><strong>Flight Date:</strong> ${ticket.flightDate}</p>
            <p><strong>Issuer:</strong> ${ticket.issuerName}</p>
            <p><strong>Status Comment:</strong> ${ticket.statusComment || '—'}</p>
            ${ticket.ticketType === 'Re-issue' ? `<p><strong>Reissue Reason:</strong> ${ticket.reissueReason}</p>` : ''}
            ${ticket.reissueReason === 'Upgrade' ? `<p><strong>Upgrade Reason:</strong> ${ticket.upgradeReason}</p>` : ''}
            ${ticket.reissueReason === 'Downgrade' ? `<p><strong>Downgrade Reason:</strong> ${ticket.downgradeReason}</p>` : ''}
            ${ticket.reissueReason === 'Rebook' ? `<p><strong>Rebook Reason:</strong> ${ticket.rebookReason}</p>` : ''}
            ${ticket.ticketStatus === 'Refunded' ? `<p><strong>Refund Recipient:</strong> ${ticket.refundRecipient || '—'}</p>` : ''}
            <p><strong>Created By:</strong> ${ticket.createdBy}</p>
            <p><strong>Created At:</strong> ${new Date(ticket.createdAt).toLocaleString()}</p>
        </div>
    `;
    previewPane.style.display = 'block';
}

function renderUsersTable() {
    const tbody = document.getElementById('usersTableBody');
    if (!tbody) return;
    tbody.innerHTML = '';
    users.forEach((user) => {
        // Check if temporary role has expired
        let displayRole = user.role;
        let roleDisplay = user.role;
        if (user.isTemporary && user.tempSupervisorEnd) {
            const endDate = new Date(user.tempSupervisorEnd);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            endDate.setHours(0, 0, 0, 0);
            
            if (today <= endDate) {
                const daysLeft = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));
                roleDisplay = `${user.role} (⏳ ${daysLeft} days)`;
            } else {
                displayRole = 'user';
                roleDisplay = `${user.role} (⚠️ Expired)`;
            }
        }
        
        const row = document.createElement('tr');
        const tempInfo = user.tempSupervisorStart ? `${user.tempSupervisorStart} to ${user.tempSupervisorEnd}` : 'N/A';
        row.innerHTML = `
            <td>${user.name}</td>
            <td>${user.email}</td>
            <td>${roleDisplay}</td>
            <td>${new Date(user.createdAt).toLocaleDateString()}</td>
        `;
        tbody.appendChild(row);
    });
}

function filterAndRenderTickets() {
    currentPage = 1;
    renderTicketsTable();
}

function updateSelectAllExportCheckbox() {
    const selector = document.getElementById('selectAllExportCheck');
    if (!selector) return;
    const checkboxes = document.querySelectorAll('.export-row-checkbox');
    const selected = Array.from(checkboxes).filter((input) => input.checked);
    selector.checked = checkboxes.length > 0 && selected.length === checkboxes.length;
}

function toggleSelectAllExportRows(source) {
    const checkboxes = document.querySelectorAll('.export-row-checkbox');
    checkboxes.forEach((input) => {
        input.checked = source.checked;
    });
}

function getSelectedExportTickets() {
    const selectedIds = Array.from(document.querySelectorAll('.export-row-checkbox:checked')).map((input) => input.value);
    return tickets.filter((ticket) => selectedIds.includes(ticket.id));
}

function exportSelectedToCsv() {
    const selected = getSelectedExportTickets().filter(t => !t.deleted);
    if (!selected.length) {
        return alert('Select at least one ticket row to export.');
    }
    downloadCsv(selected, 'selected-tickets.csv');
}

function exportAllTicketsToCsv() {
    const available = tickets.filter(t => !t.deleted);
    if (!available.length) {
        return alert('No tickets available to export.');
    }
    downloadCsv(available, 'all-tickets.csv');
}

function downloadCsv(data, filename) {
    const headers = [
        'Ticket Number',
        'Type',
        'Status',
        'Issue Date',
        'Issuer',
        'Flight Date',
        'Comment',
        'Reissue Reason',
        'Upgrade Reason',
        'Downgrade Reason',
        'Rebook Reason',
        'Refund Recipient',
        'Created By',
        'Created At',
    ];
    const rows = data.map((ticket) => [
        ticket.ticketNum,
        ticket.ticketType,
        ticket.ticketStatus,
        ticket.issueDate,
        ticket.issuerName,
        ticket.flightDate,
        ticket.statusComment,
        ticket.reissueReason,
        ticket.upgradeReason,
        ticket.downgradeReason,
        ticket.rebookReason,
        ticket.refundRecipient,
        ticket.createdBy,
        ticket.createdAt,
    ]);

    const csvContent = [headers, ...rows]
        .map((row) => row.map((value) => `"${String(value || '').replace(/"/g, '""')}"`).join(','))
        .join('\r\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function changePage(delta) {
    const filtered = getFilteredTickets();
    const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    currentPage = Math.min(Math.max(1, currentPage + delta), pages);
    renderTicketsTable();
}

// Archived tickets rendering + navigation
function getArchivedTickets() {
    return tickets.filter(t => t.deleted);
}

function renderArchivedTable() {
    const tableBody = document.getElementById('archivedTableBody');
    const pageInfo = document.getElementById('archivedPaginationDisplay');
    if (!tableBody || !pageInfo) return;

    const all = getArchivedTickets();
    const pages = Math.max(1, Math.ceil(all.length / PAGE_SIZE));
    if (archivedPage > pages) archivedPage = pages;
    if (archivedPage < 1) archivedPage = 1;
    const start = (archivedPage - 1) * PAGE_SIZE;
    const pageItems = all.slice(start, start + PAGE_SIZE);

    tableBody.innerHTML = '';
    pageItems.forEach((ticket) => {
        const row = document.createElement('tr');
        const cells = [
            ticket.ticketNum,
            ticket.ticketType,
            ticket.ticketStatus,
            ticket.issueDate,
            ticket.issuerName,
            ticket.flightDate,
            ticket.statusComment,
            ticket.createdBy,
        ];
        cells.forEach((v) => {
            const td = document.createElement('td');
            td.textContent = v || '-';
            row.appendChild(td);
        });
        const actionTd = document.createElement('td');
        const restoreBtn = document.createElement('button');
        restoreBtn.textContent = 'Restore';
        restoreBtn.className = 'mini-btn';
        restoreBtn.onclick = () => restoreTicket(ticket.id);
        actionTd.appendChild(restoreBtn);
        row.appendChild(actionTd);
        tableBody.appendChild(row);
    });

    pageInfo.innerHTML = `Page ${archivedPage} of ${pages} <select id="archivedPageSelect" onchange="goToArchivedPage(this.value)"></select>`;
    const sel = document.getElementById('archivedPageSelect');
    if (sel) {
        for (let i = 1; i <= pages; i++) {
            const opt = document.createElement('option');
            opt.value = i;
            opt.text = i;
            if (i === archivedPage) opt.selected = true;
            sel.appendChild(opt);
        }
    }
}

function goToArchivedPage(page) {
    page = parseInt(page, 10) || 1;
    archivedPage = page;
    renderArchivedTable();
}

function changeArchivedPage(delta) {
    const all = getArchivedTickets();
    const pages = Math.max(1, Math.ceil(all.length / PAGE_SIZE));
    archivedPage = Math.min(Math.max(1, archivedPage + delta), pages);
    renderArchivedTable();
}

function toggleArchivedSection() {
    const sec = document.getElementById('archived-section');
    if (!sec) return;
    sec.style.display = sec.style.display === 'block' ? 'none' : 'block';
    if (sec.style.display === 'block') renderArchivedTable();
}

function restoreTicket(ticketId) {
    const role = (currentUserRole || getLocalUserRole(activeUser?.email) || '').toLowerCase();
    if (role !== 'admin') return alert('Only admins can restore archived tickets.');
    const t = tickets.find(x => x.id === ticketId);
    if (!t) return alert('Ticket not found');
    t.deleted = false;
    delete t.deletedAt;
    delete t.deletedBy;
    persistTickets();
    renderArchivedTable();
    renderTicketsTable();
    alert('Ticket restored.');
}

function closeInspectionPane() {
    const pane = document.getElementById('sidePreviewPane');
    if (pane) pane.style.display = 'none';
}

function printSelectedTicketReceipt() {
    const previewContent = document.getElementById('previewPaneContent');
    const pdfArea = document.getElementById('pdfPrintArea');
    const pdfModal = document.getElementById('pdfModal');
    if (!previewContent || !pdfArea || !pdfModal) return;

    pdfArea.innerHTML = previewContent.innerHTML;
    pdfModal.style.display = 'flex';
}

function triggerBrowserPrintDialog() {
    window.print();
}

function closePdfModal() {
    const modal = document.getElementById('pdfModal');
    if (modal) modal.style.display = 'none';
}

function toggleTemporarySupervisorFields() {
    const roleSelect = document.getElementById('newUserRole');
    const tempFields = document.getElementById('temporary-supervisor-fields');
    if (!roleSelect || !tempFields) return;
    
    tempFields.style.display = roleSelect.value === 'supervisor' ? 'block' : 'none';
}

window.addEventListener('DOMContentLoaded', () => {
    try {
        initializeTheme();
    } catch (e) {
        console.warn('Theme initialization failed', e);
    }
    try {
        initializeLanguage();
    } catch (e) {
        console.warn('Language initialization failed', e);
    }
    initAuth();
});

/* ==========================================================================
   PETITPAS - INTERACTIVE WEB APP ENGINE
   Full UI Customization, QR Scanning & Photo Management
   ========================================================================== */

// --- INITIAL STATE & DEFAULT MOCK DATA ---
const DEFAULT_STATE = {
  classInfo: {
    name: "Classe Petite Section (PS)",
    teacher: "Mme Dupont",
    level: "PS",
    schoolYear: "2026-2027"
  },
  children: [
    { id: "child_1", firstname: "Léo", lastname: "Martin", birthdate: "2023-04-12", group: "Groupe Rouge", notes: "", color: "#4E9F3D", avatarText: "LM" },
    { id: "child_2", firstname: "Emma", lastname: "Petit", birthdate: "2023-07-22", group: "Groupe Bleu", notes: "Doudou lapin pour la sieste", color: "#FF7043", avatarText: "EP" },
    { id: "child_3", firstname: "Lucas", lastname: "Bernard", birthdate: "2023-02-18", group: "Groupe Rouge", notes: "", color: "#7E57C2", avatarText: "LB" },
    { id: "child_4", firstname: "Chloé", lastname: "Dubois", birthdate: "2023-09-05", group: "Groupe Jaune", notes: "Lunettes de vue", color: "#FFA726", avatarText: "CD" },
    { id: "child_5", firstname: "Tom", lastname: "Moreau", birthdate: "2023-01-30", group: "Groupe Bleu", notes: "", color: "#26A69A", avatarText: "TM" },
    { id: "child_6", firstname: "Inès", lastname: "Leroy", birthdate: "2023-11-14", group: "Groupe Jaune", notes: "Très créative, aime chanter", color: "#EC407A", avatarText: "IL" }
  ],
  activityTypes: [
    { id: "act_1", name: "Atelier Peinture & Arts", category: "Créatif", icon: "fa-paintbrush", color: "#FF7043" },
    { id: "act_2", name: "Motricité & Parcours", category: "Motricité", icon: "fa-shapes", color: "#4E9F3D" },
    { id: "act_3", name: "Coin Lecture & Contes", category: "Apprentissage", icon: "fa-book-open", color: "#7E57C2" },
    { id: "act_4", name: "Graphisme & Tracés", category: "Apprentissage", icon: "fa-scissors", color: "#FFA726" },
    { id: "act_5", name: "Sieste & Temps Calme", category: "Bien-être", icon: "fa-bed", color: "#42A5F5" },
    { id: "act_6", name: "Repas & Goûter", category: "Vie pratique", icon: "fa-apple-whole", color: "#8D6E63" }
  ],
  emotions: [
    { label: "Joyeux", emoji: "😊" },
    { label: "Concentré", emoji: "🎯" },
    { label: "Calme", emoji: "😌" },
    { label: "Attentif", emoji: "🧐" },
    { label: "Fatigué", emoji: "😴" },
    { label: "Créatif", emoji: "🎨" }
  ],
  activities: [
    {
      id: "log_1",
      childId: "child_1",
      activityTypeId: "act_1",
      timestamp: new Date(Date.now() - 3600000).toISOString(),
      emotion: "Joyeux 😊",
      note: "A mélangé du bleu et du jaune pour créer du vert !",
      photoUrl: "https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=400&auto=format&fit=crop&q=80"
    },
    {
      id: "log_2",
      childId: "child_2",
      activityTypeId: "act_2",
      timestamp: new Date(Date.now() - 7200000).toISOString(),
      emotion: "Concentré 🎯",
      note: "A franchi la poutre d'équilibre sans aide.",
      photoUrl: null
    },
    {
      id: "log_3",
      childId: "child_3",
      activityTypeId: "act_3",
      timestamp: new Date(Date.now() - 10800000).toISOString(),
      emotion: "Calme 😌",
      note: "A écouté attentivement l'histoire de Boucle d'Or.",
      photoUrl: null
    }
  ]
};

// State Manager
let state = { ...DEFAULT_STATE };

// Temporary Scan Match State
let currentScanState = {
  childId: null,
  activityTypeId: null,
  selectedEmotion: "Joyeux 😊",
  photoUrl: null
};

// --- APP INITIALIZATION ---
document.addEventListener("DOMContentLoaded", () => {
  loadStateFromLocalStorage();
  initNavigation();
  initThemeToggle();
  initDashboard();
  initScanAndGoScreen();
  initChildrenScreen();
  initQRStudio();
  initSettingsScreen();
  initModals();
});

// --- PERSISTENCE ---
function loadStateFromLocalStorage() {
  const saved = localStorage.getItem("petitpas_app_state");
  if (saved) {
    try {
      state = JSON.parse(saved);
    } catch (e) {
      console.error("Error parsing local storage, restoring defaults", e);
      state = { ...DEFAULT_STATE };
    }
  } else {
    saveStateToLocalStorage();
  }
}

function saveStateToLocalStorage() {
  localStorage.setItem("petitpas_app_state", JSON.stringify(state));
}

// --- NAVIGATION ---
function initNavigation() {
  const navItems = document.querySelectorAll(".nav-item");
  navItems.forEach(item => {
    item.addEventListener("click", () => {
      const targetId = item.getAttribute("data-target");
      switchScreen(targetId);
    });
  });

  const quickScanBtn = document.getElementById("btn-quick-scan");
  if (quickScanBtn) {
    quickScanBtn.addEventListener("click", () => {
      switchScreen("screen-scan");
    });
  }
}

function switchScreen(screenId) {
  document.querySelectorAll(".nav-item").forEach(i => i.classList.remove("active"));
  document.querySelectorAll(".screen-view").forEach(s => s.classList.remove("active"));

  const targetNav = document.querySelector(`.nav-item[data-target="${screenId}"]`);
  const targetScreen = document.getElementById(screenId);

  if (targetNav) targetNav.classList.add("active");
  if (targetScreen) targetScreen.classList.add("active");

  // Refresh dynamic views when navigating
  if (screenId === "screen-dashboard") renderDashboardTimeline();
  if (screenId === "screen-children") renderChildrenGrid();
  if (screenId === "screen-qr-print") renderQRSheets();
  if (screenId === "screen-scan") populateScanSimulators();
}

// --- THEME TOGGLE ---
function initThemeToggle() {
  const btn = document.getElementById("btn-toggle-theme");
  btn.addEventListener("click", () => {
    const isDark = document.body.getAttribute("data-theme") === "dark";
    if (isDark) {
      document.body.removeAttribute("data-theme");
      btn.innerHTML = `<i class="fa-solid fa-moon"></i>`;
    } else {
      document.body.setAttribute("data-theme", "dark");
      btn.innerHTML = `<i class="fa-solid fa-sun"></i>`;
    }
  });
}

// --- DASHBOARD ---
function initDashboard() {
  renderDashboardHeader();
  renderDashboardCategoryPills();
  renderDashboardTimeline();
}

function renderDashboardHeader() {
  document.getElementById("header-class-name").textContent = state.classInfo.name;
  document.getElementById("stat-present-count").textContent = `${state.children.length} / ${state.children.length}`;
  document.getElementById("stat-today-activities").textContent = state.activities.length;
  
  const photosCount = state.activities.filter(a => a.photoUrl).length;
  document.getElementById("stat-photos-count").textContent = photosCount;
}

function renderDashboardCategoryPills() {
  const container = document.getElementById("dashboard-category-filters");
  container.innerHTML = `<button class="pill active" data-cat="all">Tous</button>`;

  const categories = [...new Set(state.activityTypes.map(a => a.category))];
  categories.forEach(cat => {
    const btn = document.createElement("button");
    btn.className = "pill";
    btn.setAttribute("data-cat", cat);
    btn.textContent = cat;
    btn.addEventListener("click", () => {
      container.querySelectorAll(".pill").forEach(p => p.classList.remove("active"));
      btn.classList.add("active");
      renderDashboardTimeline(cat);
    });
    container.appendChild(btn);
  });
}

function renderDashboardTimeline(filterCat = "all") {
  const timelineList = document.getElementById("timeline-list");
  timelineList.innerHTML = "";

  renderDashboardHeader();

  let filteredActivities = [...state.activities];
  if (filterCat !== "all") {
    const validActTypeIds = state.activityTypes.filter(t => t.category === filterCat).map(t => t.id);
    filteredActivities = filteredActivities.filter(a => validActTypeIds.includes(a.activityTypeId));
  }

  // Sort by latest timestamp first
  filteredActivities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  if (filteredActivities.length === 0) {
    timelineList.innerHTML = `
      <div class="match-box empty" style="padding: 40px;">
        <i class="fa-solid fa-calendar-day" style="font-size:32px; opacity:0.4; margin-bottom:12px;"></i>
        <p style="font-size:14px; font-weight:600; color:var(--text-muted)">Aucune activité enregistrée pour ce filtre.</p>
      </div>
    `;
    return;
  }

  filteredActivities.forEach(act => {
    const child = state.children.find(c => c.id === act.childId) || { firstname: "Élève", color: "#4E9F3D" };
    const actType = state.activityTypes.find(t => t.id === act.activityTypeId) || { name: "Atelier", icon: "fa-shapes", color: "#FF7043" };
    const timeStr = new Date(act.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const item = document.createElement("div");
    item.className = "timeline-item";
    item.innerHTML = `
      <div class="timeline-left">
        <div class="activity-icon-badge" style="background-color:${actType.color}">
          <i class="fa-solid ${actType.icon}"></i>
        </div>
        <span class="activity-time">${timeStr}</span>
      </div>
      <div class="timeline-body">
        <div class="timeline-top">
          <div class="child-name-badge">
            <span style="display:inline-block; width:10px; height:10px; border-radius:50%; background-color:${child.color}"></span>
            ${child.firstname} ${child.lastname ? child.lastname[0] + '.' : ''}
          </div>
          <span class="emotion-tag">${act.emotion || '😊 Joyeux'}</span>
        </div>
        <div class="activity-title">${actType.name}</div>
        ${act.note ? `<div class="activity-note"><i class="fa-solid fa-quote-left"></i> ${act.note}</div>` : ''}
        ${act.photoUrl ? `
          <div class="activity-photo-preview">
            <img src="${act.photoUrl}" alt="Photo atelier">
          </div>
        ` : ''}
      </div>
    `;
    timelineList.appendChild(item);
  });
}

// --- SCAN & GO ENGINE WITH REAL LIVE CAMERA ---
let html5QrScanner = null;

function initScanAndGoScreen() {
  populateScanSimulators();
  renderEmotionSelectors();
  initLiveCameraScanner();

  // Simulators logic (fallbacks for testing)
  document.getElementById("sim-select-child").addEventListener("change", (e) => {
    if (e.target.value) onQrCodeScanned(`PETITPAS:CHILD:${e.target.value}`);
  });

  document.getElementById("sim-select-activity").addEventListener("change", (e) => {
    if (e.target.value) onQrCodeScanned(`PETITPAS:ACT:${e.target.value}`);
  });

  document.getElementById("btn-sim-scan").addEventListener("click", () => {
    const cId = document.getElementById("sim-select-child").value || (state.children[0] ? state.children[0].id : null);
    const aId = document.getElementById("sim-select-activity").value || (state.activityTypes[0] ? state.activityTypes[0].id : null);
    
    if (cId) onQrCodeScanned(`PETITPAS:CHILD:${cId}`);
    if (aId) onQrCodeScanned(`PETITPAS:ACT:${aId}`);
    showToast("Scan simulé avec succès !");
  });

  // Photo handlers
  const photoInput = document.getElementById("scan-photo-input");
  document.getElementById("btn-trigger-photo").addEventListener("click", () => photoInput.click());

  photoInput.addEventListener("change", (e) => {
    if (e.target.files && e.target.files[0]) {
      const reader = new FileReader();
      reader.onload = (event) => {
        setCapturedPhoto(event.target.result);
      };
      reader.readAsDataURL(e.target.files[0]);
    }
  });

  document.getElementById("btn-sample-photo").addEventListener("click", () => {
    const samplePhotos = [
      "https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?w=400&auto=format&fit=crop&q=80",
      "https://images.unsplash.com/photo-1596464716127-f2a82984de30?w=400&auto=format&fit=crop&q=80",
      "https://images.unsplash.com/photo-1544717305-2782549b5136?w=400&auto=format&fit=crop&q=80"
    ];
    const picked = samplePhotos[Math.floor(Math.random() * samplePhotos.length)];
    setCapturedPhoto(picked);
  });

  document.getElementById("btn-remove-photo").addEventListener("click", () => {
    setCapturedPhoto(null);
  });

  // Confirm Association
  document.getElementById("btn-confirm-association").addEventListener("click", () => {
    if (!currentScanState.childId || !currentScanState.activityTypeId) return;

    const newActivity = {
      id: "log_" + Date.now(),
      childId: currentScanState.childId,
      activityTypeId: currentScanState.activityTypeId,
      timestamp: new Date().toISOString(),
      emotion: currentScanState.selectedEmotion,
      note: document.getElementById("scan-note-input").value.trim(),
      photoUrl: currentScanState.photoUrl
    };

    state.activities.unshift(newActivity);
    saveStateToLocalStorage();

    showToast("Activité enregistrée avec succès !");

    // Reset scan state
    currentScanState.childId = null;
    currentScanState.activityTypeId = null;
    currentScanState.photoUrl = null;
    document.getElementById("sim-select-child").value = "";
    document.getElementById("sim-select-activity").value = "";
    document.getElementById("scan-note-input").value = "";
    setCapturedPhoto(null);
    updateScanMatchUI();

    // Navigate to dashboard to show result
    setTimeout(() => switchScreen("screen-dashboard"), 800);
  });
}

function initLiveCameraScanner() {
  const cameraContainer = document.getElementById("camera-feed");
  if (!cameraContainer) return;

  // Add real video element container if not existing
  if (!document.getElementById("interactive-qr-reader")) {
    const videoDiv = document.createElement("div");
    videoDiv.id = "interactive-qr-reader";
    videoDiv.style.width = "100%";
    videoDiv.style.height = "100%";
    cameraContainer.appendChild(videoDiv);
  }

  // Start real HTML5 QR scanner if library loaded
  if (typeof Html5Qrcode !== "undefined") {
    try {
      const html5QrCode = new Html5Qrcode("interactive-qr-reader");
      const config = { fps: 10, qrbox: { width: 220, height: 220 } };

      html5QrCode.start(
        { facingMode: "environment" },
        config,
        (decodedText, decodedResult) => {
          onQrCodeScanned(decodedText);
        },
        (errorMessage) => {
          // ignore frame scan errors
        }
      ).catch(err => {
        console.warn("Unable to start live camera (probably HTTP instead of HTTPS):", err);
        const statusText = document.getElementById("camera-status-text");
        if (statusText) {
          statusText.innerHTML = `
            <span style="color:#FFA726; font-size:13px; font-weight:bold;">
              <i class="fa-solid fa-lock"></i> Note iOS Safari :<br>
              Pour activer la caméra vidéo en direct, ouvrez en <b>HTTPS</b><br>
              (ex: via Netlify/Vercel) ou utilisez la simulation ci-dessous.
            </span>
          `;
        }
      });
    } catch (e) {
      console.log("Scanner init error", e);
    }
  }
}

function onQrCodeScanned(decodedText) {
  if (decodedText.startsWith("PETITPAS:CHILD:")) {
    const childId = decodedText.replace("PETITPAS:CHILD:", "");
    if (state.children.some(c => c.id === childId)) {
      currentScanState.childId = childId;
      document.getElementById("sim-select-child").value = childId;
      updateScanMatchUI();
      if (navigator.vibrate) navigator.vibrate(100);
      showToast("Élève identifié !");
    }
  } else if (decodedText.startsWith("PETITPAS:ACT:")) {
    const actId = decodedText.replace("PETITPAS:ACT:", "");
    if (state.activityTypes.some(a => a.id === actId)) {
      currentScanState.activityTypeId = actId;
      document.getElementById("sim-select-activity").value = actId;
      updateScanMatchUI();
      if (navigator.vibrate) navigator.vibrate(100);
      showToast("Atelier identifié !");
    }
  }
}

function setCapturedPhoto(url) {
  currentScanState.photoUrl = url;
  const previewBox = document.getElementById("scan-photo-preview");
  const imgEl = document.getElementById("scan-photo-img");

  if (url) {
    imgEl.src = url;
    previewBox.style.display = "block";
  } else {
    imgEl.src = "";
    previewBox.style.display = "none";
  }
}

function renderEmotionSelectors() {
  const container = document.getElementById("scan-emotion-selector");
  container.innerHTML = "";

  state.emotions.forEach((emo, index) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = `emotion-btn ${index === 0 ? 'selected' : ''}`;
    btn.textContent = `${emo.emoji} ${emo.label}`;
    btn.addEventListener("click", () => {
      container.querySelectorAll(".emotion-btn").forEach(b => b.classList.remove("selected"));
      btn.classList.add("selected");
      currentScanState.selectedEmotion = `${emo.label} ${emo.emoji}`;
    });
    container.appendChild(btn);
  });
}

function populateScanSimulators() {
  const childSelect = document.getElementById("sim-select-child");
  const actSelect = document.getElementById("sim-select-activity");

  childSelect.innerHTML = `<option value="">-- Choisir un Élève --</option>`;
  state.children.forEach(c => {
    childSelect.innerHTML += `<option value="${c.id}">${c.firstname} ${c.lastname || ''}</option>`;
  });

  actSelect.innerHTML = `<option value="">-- Choisir un Atelier --</option>`;
  state.activityTypes.forEach(a => {
    actSelect.innerHTML += `<option value="${a.id}">${a.name}</option>`;
  });
}

function updateScanMatchUI() {
  const childBox = document.getElementById("box-matched-child");
  const childContent = document.getElementById("content-matched-child");
  const actBox = document.getElementById("box-matched-activity");
  const actContent = document.getElementById("content-matched-activity");
  const confirmBtn = document.getElementById("btn-confirm-association");

  if (currentScanState.childId) {
    const child = state.children.find(c => c.id === currentScanState.childId);
    childBox.classList.add("matched");
    childContent.className = "match-content";
    childContent.innerHTML = `
      <div class="child-avatar" style="background-color:${child.color}; width:42px; height:42px;">${child.avatarText || child.firstname[0]}</div>
      <span>${child.firstname} ${child.lastname || ''}</span>
    `;
  } else {
    childBox.classList.remove("matched");
    childContent.className = "match-content empty";
    childContent.innerHTML = `<i class="fa-solid fa-qrcode placeholder-qr-icon"></i><span>Veuillez scanner le QR Code élève</span>`;
  }

  if (currentScanState.activityTypeId) {
    const act = state.activityTypes.find(a => a.id === currentScanState.activityTypeId);
    actBox.classList.add("matched");
    actContent.className = "match-content";
    actContent.innerHTML = `
      <div class="activity-icon-badge" style="background-color:${act.color}; width:42px; height:42px; font-size:18px;">
        <i class="fa-solid ${act.icon}"></i>
      </div>
      <span>${act.name}</span>
    `;
  } else {
    actBox.classList.remove("matched");
    actContent.className = "match-content empty";
    actContent.innerHTML = `<i class="fa-solid fa-qrcode placeholder-qr-icon"></i><span>Veuillez scanner le QR Code de l'atelier</span>`;
  }

  confirmBtn.disabled = !(currentScanState.childId && currentScanState.activityTypeId);
}

// --- CHILDREN SCREEN ---
function initChildrenScreen() {
  renderChildrenGrid();

  document.getElementById("input-search-child").addEventListener("input", (e) => {
    const q = e.target.value.toLowerCase();
    renderChildrenGrid(q);
  });

  document.getElementById("btn-add-child").addEventListener("click", () => {
    openChildModal();
  });
}

function renderChildrenGrid(query = "") {
  const container = document.getElementById("children-cards-container");
  container.innerHTML = "";

  const filtered = state.children.filter(c => 
    c.firstname.toLowerCase().includes(query) ||
    (c.lastname && c.lastname.toLowerCase().includes(query)) ||
    (c.group && c.group.toLowerCase().includes(query))
  );

  document.getElementById("children-count").textContent = filtered.length;

  filtered.forEach(child => {
    const card = document.createElement("div");
    card.className = "child-card";
    card.innerHTML = `
      <div class="child-card-header">
        <div class="child-avatar" style="background-color:${child.color}">
          ${child.avatarText || child.firstname[0]}
        </div>
        <div class="child-meta">
          <span class="child-fullname">${child.firstname} ${child.lastname || ''}</span>
          <span class="child-group-tag">${child.group || 'Sans groupe'}</span>
        </div>
      </div>
      ${child.notes ? `<div class="child-notes-badge"><i class="fa-solid fa-circle-exclamation"></i> ${child.notes}</div>` : ''}
      <div class="child-card-actions">
        <button class="btn btn-outline btn-sm col-6" onclick="openChildReportModal('${child.id}')">
          <i class="fa-solid fa-file-invoice"></i> Fiche Parent
        </button>
        <button class="btn btn-outline btn-sm" onclick="openChildModal('${child.id}')">
          <i class="fa-solid fa-pen"></i>
        </button>
        <button class="btn btn-danger-outline btn-sm" onclick="deleteChild('${child.id}')">
          <i class="fa-solid fa-trash"></i>
        </button>
      </div>
    `;
    container.appendChild(card);
  });
}

function deleteChild(childId) {
  if (confirm("Voulez-vous vraiment supprimer cet élève ?")) {
    state.children = state.children.filter(c => c.id !== childId);
    saveStateToLocalStorage();
    renderChildrenGrid();
    showToast("Élève supprimé");
  }
}

// --- QR CODE PRINT STUDIO ---
function initQRStudio() {
  const tabBtns = document.querySelectorAll(".tab-btn");
  tabBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      tabBtns.forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      const tabId = btn.getAttribute("data-tab");
      document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));
      document.getElementById(tabId).classList.add("active");
    });
  });

  renderQRSheets();
}

function renderQRSheets() {
  renderStudentQRBadges();
  renderActivityQRCards();
}

function renderStudentQRBadges() {
  const container = document.getElementById("qr-students-sheet");
  container.innerHTML = "";

  state.children.forEach(child => {
    const badge = document.createElement("div");
    badge.className = "qr-badge-item";
    const qrId = `qr_child_${child.id}`;
    badge.innerHTML = `
      <div class="badge-title">${child.firstname} ${child.lastname || ''}</div>
      <div class="badge-subtitle">${child.group || state.classInfo.name}</div>
      <div class="qr-code-box" id="${qrId}"></div>
      <div style="font-size:10px; color:#94A3B8;">BADGE ÉLÈVE PETITPAS</div>
    `;
    container.appendChild(badge);

    // Generate QR Code via QRCode library
    setTimeout(() => {
      new QRCode(document.getElementById(qrId), {
        text: `PETITPAS:CHILD:${child.id}`,
        width: 100,
        height: 100,
        colorDark: "#1E293B",
        colorLight: "#ffffff"
      });
    }, 50);
  });
}

function renderActivityQRCards() {
  const container = document.getElementById("qr-activities-sheet");
  container.innerHTML = "";

  state.activityTypes.forEach(act => {
    const card = document.createElement("div");
    card.className = "qr-badge-item";
    const qrId = `qr_act_${act.id}`;
    card.innerHTML = `
      <div class="activity-icon-badge" style="background-color:${act.color}; width:44px; height:44px;">
        <i class="fa-solid ${act.icon}"></i>
      </div>
      <div class="badge-title">${act.name}</div>
      <div class="badge-subtitle">ATELIER MATERNELLE - ${act.category}</div>
      <div class="qr-code-box" id="${qrId}"></div>
      <div style="font-size:10px; color:#94A3B8;">SCANNER EN CLASSE</div>
    `;
    container.appendChild(card);

    setTimeout(() => {
      new QRCode(document.getElementById(qrId), {
        text: `PETITPAS:ACT:${act.id}`,
        width: 110,
        height: 110,
        colorDark: act.color,
        colorLight: "#ffffff"
      });
    }, 50);
  });
}

// --- SETTINGS ENGINE SCREEN ---
function initSettingsScreen() {
  // Class Settings Form
  document.getElementById("setting-class-name").value = state.classInfo.name;
  document.getElementById("setting-teacher-name").value = state.classInfo.teacher;
  document.getElementById("setting-class-level").value = state.classInfo.level;
  document.getElementById("setting-school-year").value = state.classInfo.schoolYear;

  document.getElementById("btn-save-class-settings").addEventListener("click", () => {
    state.classInfo.name = document.getElementById("setting-class-name").value;
    state.classInfo.teacher = document.getElementById("setting-teacher-name").value;
    state.classInfo.level = document.getElementById("setting-class-level").value;
    state.classInfo.schoolYear = document.getElementById("setting-school-year").value;
    saveStateToLocalStorage();
    renderDashboardHeader();
    showToast("Paramètres de la classe enregistrés");
  });

  // Activity Types Config List
  renderActivityTypesConfigList();
  document.getElementById("btn-add-activity-type").addEventListener("click", () => {
    openActivityTypeModal();
  });

  // Emotions Config Tags
  renderEmotionsConfigTags();
  document.getElementById("btn-add-emotion").addEventListener("click", () => {
    const lbl = document.getElementById("input-new-emotion-label").value.trim();
    const emo = document.getElementById("input-new-emotion-emoji").value.trim() || "😊";
    if (lbl) {
      state.emotions.push({ label: lbl, emoji: emo });
      saveStateToLocalStorage();
      renderEmotionsConfigTags();
      renderEmotionSelectors();
      document.getElementById("input-new-emotion-label").value = "";
      showToast("Émotion ajoutée");
    }
  });

  // Backup / Export / Import / Reset
  document.getElementById("btn-export-data").addEventListener("click", () => {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(state, null, 2));
    const dlAnchorElem = document.createElement('a');
    dlAnchorElem.setAttribute("href", dataStr);
    dlAnchorElem.setAttribute("download", `petitpas_export_${new Date().toISOString().slice(0,10)}.json`);
    dlAnchorElem.click();
  });

  const importInput = document.getElementById("input-import-file");
  document.getElementById("btn-import-trigger").addEventListener("click", () => importInput.click());

  importInput.addEventListener("change", (e) => {
    if (e.target.files && e.target.files[0]) {
      const reader = new FileReader();
      reader.onload = (evt) => {
        try {
          const imported = JSON.parse(evt.target.result);
          if (imported.children && imported.activityTypes) {
            state = imported;
            saveStateToLocalStorage();
            location.reload();
          }
        } catch (err) {
          alert("Fichier de sauvegarde invalide.");
        }
      };
      reader.readAsText(e.target.files[0]);
    }
  });

  document.getElementById("btn-reset-demo").addEventListener("click", () => {
    if (confirm("Réinitialiser avec les données de démonstration ?")) {
      state = { ...DEFAULT_STATE };
      saveStateToLocalStorage();
      location.reload();
    }
  });
}

function renderActivityTypesConfigList() {
  const container = document.getElementById("activity-types-config-list");
  container.innerHTML = "";

  state.activityTypes.forEach(act => {
    const item = document.createElement("div");
    item.className = "timeline-item";
    item.style.marginBottom = "10px";
    item.innerHTML = `
      <div class="activity-icon-badge" style="background-color:${act.color}">
        <i class="fa-solid ${act.icon}"></i>
      </div>
      <div style="flex:1">
        <h4 style="font-size:15px; font-weight:700">${act.name}</h4>
        <span style="font-size:12px; color:var(--text-muted)">Catégorie : ${act.category}</span>
      </div>
      <div class="action-buttons">
        <button class="btn btn-outline btn-sm" onclick="openActivityTypeModal('${act.id}')"><i class="fa-solid fa-pen"></i></button>
        <button class="btn btn-danger-outline btn-sm" onclick="deleteActivityType('${act.id}')"><i class="fa-solid fa-trash"></i></button>
      </div>
    `;
    container.appendChild(item);
  });
}

function deleteActivityType(id) {
  if (confirm("Supprimer cet atelier ?")) {
    state.activityTypes = state.activityTypes.filter(a => a.id !== id);
    saveStateToLocalStorage();
    renderActivityTypesConfigList();
    renderDashboardCategoryPills();
    showToast("Atelier supprimé");
  }
}

function renderEmotionsConfigTags() {
  const container = document.getElementById("emotions-config-tags");
  container.innerHTML = "";

  state.emotions.forEach((emo, index) => {
    const tag = document.createElement("span");
    tag.className = "emotion-btn selected";
    tag.style.marginRight = "6px";
    tag.style.marginBottom = "6px";
    tag.innerHTML = `${emo.emoji} ${emo.label} <i class="fa-solid fa-xmark" style="margin-left:6px; cursor:pointer;" onclick="removeEmotion(${index})"></i>`;
    container.appendChild(tag);
  });
}

function removeEmotion(index) {
  state.emotions.splice(index, 1);
  saveStateToLocalStorage();
  renderEmotionsConfigTags();
  renderEmotionSelectors();
}

// --- MODALS & DIALOGS ---
function initModals() {
  document.getElementById("btn-manual-add").addEventListener("click", () => {
    switchScreen("screen-scan");
  });

  document.getElementById("btn-save-child").addEventListener("click", () => {
    const firstname = document.getElementById("child-firstname").value.trim();
    if (!firstname) return alert("Le prénom est obligatoire");

    const id = document.getElementById("child-id").value || ("child_" + Date.now());
    const lastname = document.getElementById("child-lastname").value.trim();
    const birthdate = document.getElementById("child-birthdate").value;
    const group = document.getElementById("child-group").value.trim();
    const notes = document.getElementById("child-notes").value.trim();
    const color = document.getElementById("child-color").value;

    const avatarText = firstname[0] + (lastname ? lastname[0] : '');

    const existingIdx = state.children.findIndex(c => c.id === id);
    const childData = { id, firstname, lastname, birthdate, group, notes, color, avatarText: avatarText.toUpperCase() };

    if (existingIdx >= 0) {
      state.children[existingIdx] = childData;
    } else {
      state.children.push(childData);
    }

    saveStateToLocalStorage();
    closeModal("modal-child");
    renderChildrenGrid();
    populateScanSimulators();
    showToast("Élève enregistré !");
  });

  document.getElementById("btn-save-activity-type").addEventListener("click", () => {
    const name = document.getElementById("act-type-name").value.trim();
    if (!name) return alert("Le nom est obligatoire");

    const id = document.getElementById("act-type-id").value || ("act_" + Date.now());
    const category = document.getElementById("act-type-category").value;
    const icon = document.getElementById("act-type-icon").value;
    const color = document.getElementById("act-type-color").value;

    const existingIdx = state.activityTypes.findIndex(a => a.id === id);
    const actData = { id, name, category, icon, color };

    if (existingIdx >= 0) {
      state.activityTypes[existingIdx] = actData;
    } else {
      state.activityTypes.push(actData);
    }

    saveStateToLocalStorage();
    closeModal("modal-activity-type");
    renderActivityTypesConfigList();
    renderDashboardCategoryPills();
    populateScanSimulators();
    showToast("Atelier enregistré !");
  });
}

function openChildModal(childId = null) {
  document.getElementById("form-child").reset();
  if (childId) {
    const c = state.children.find(ch => ch.id === childId);
    if (c) {
      document.getElementById("modal-child-title").textContent = "Modifier l'Élève";
      document.getElementById("child-id").value = c.id;
      document.getElementById("child-firstname").value = c.firstname;
      document.getElementById("child-lastname").value = c.lastname || '';
      document.getElementById("child-birthdate").value = c.birthdate || '';
      document.getElementById("child-group").value = c.group || '';
      document.getElementById("child-notes").value = c.notes || '';
      document.getElementById("child-color").value = c.color || '#4E9F3D';
    }
  } else {
    document.getElementById("modal-child-title").textContent = "Ajouter un Élève";
    document.getElementById("child-id").value = "";
  }
  document.getElementById("modal-child").style.display = "flex";
}

function openActivityTypeModal(actId = null) {
  document.getElementById("form-activity-type").reset();
  if (actId) {
    const a = state.activityTypes.find(ac => ac.id === actId);
    if (a) {
      document.getElementById("modal-act-title").textContent = "Modifier l'Atelier";
      document.getElementById("act-type-id").value = a.id;
      document.getElementById("act-type-name").value = a.name;
      document.getElementById("act-type-category").value = a.category;
      document.getElementById("act-type-icon").value = a.icon;
      document.getElementById("act-type-color").value = a.color;
    }
  } else {
    document.getElementById("modal-act-title").textContent = "Ajouter un Type d'Atelier";
    document.getElementById("act-type-id").value = "";
  }
  document.getElementById("modal-activity-type").style.display = "flex";
}

function openChildReportModal(childId) {
  const child = state.children.find(c => c.id === childId);
  if (!child) return;

  const childActivities = state.activities.filter(a => a.childId === childId);
  const container = document.getElementById("child-report-body");

  let activitiesHTML = childActivities.length === 0 ? 
    `<p style="color:var(--text-muted)">Aucune activité enregistrée aujourd'hui pour cet élève.</p>` :
    childActivities.map(a => {
      const actType = state.activityTypes.find(t => t.id === a.activityTypeId) || { name: 'Atelier', icon: 'fa-shapes', color: '#4E9F3D' };
      const timeStr = new Date(a.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      return `
        <div class="timeline-item" style="margin-bottom:10px">
          <div class="activity-icon-badge" style="background-color:${actType.color}; width:36px; height:36px; font-size:14px;">
            <i class="fa-solid ${actType.icon}"></i>
          </div>
          <div style="flex:1">
            <div style="font-weight:700">${actType.name} <span style="font-size:12px; font-weight:normal; color:var(--text-muted)">(${timeStr})</span></div>
            <div style="font-size:12px; color:var(--text-muted)">Humeur : ${a.emotion || '😊'}</div>
            ${a.note ? `<div style="font-size:13px; margin-top:4px;">"${a.note}"</div>` : ''}
            ${a.photoUrl ? `<div class="activity-photo-preview" style="margin-top:6px;"><img src="${a.photoUrl}"></div>` : ''}
          </div>
        </div>
      `;
    }).join("");

  container.innerHTML = `
    <div style="text-align:center; margin-bottom:20px;">
      <div class="child-avatar" style="background-color:${child.color}; width:64px; height:64px; font-size:24px; margin: 0 auto 10px;">${child.avatarText || child.firstname[0]}</div>
      <h2 style="font-size:22px">${child.firstname} ${child.lastname || ''}</h2>
      <span class="child-group-tag">${child.group || state.classInfo.name}</span>
    </div>
    <div style="background:var(--bg-primary); padding:16px; border-radius:var(--border-radius-md); margin-bottom:20px;">
      <h4 style="font-size:14px; margin-bottom:6px;"><i class="fa-solid fa-circle-info"></i> Informations de transmission</h4>
      <p style="font-size:13px;"><strong>Classe :</strong> ${state.classInfo.name} (${state.classInfo.teacher})</p>
      <p style="font-size:13px;"><strong>Date :</strong> ${new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</p>
      ${child.notes ? `<p style="font-size:13px; color:#D97706;"><strong>Attention :</strong> ${child.notes}</p>` : ''}
    </div>
    <h3 style="font-size:16px; margin-bottom:12px;"><i class="fa-solid fa-list-check"></i> Résumé des activités de la journée :</h3>
    <div>${activitiesHTML}</div>
  `;

  document.getElementById("modal-child-report").style.display = "flex";
}

function closeModal(modalId) {
  document.getElementById(modalId).style.display = "none";
}

// --- UTILITY TOAST NOTIFICATION ---
function showToast(message) {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `<i class="fa-solid fa-circle-check" style="color:var(--primary); font-size:18px;"></i> <span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateX(20px)";
    toast.style.transition = "all 0.3s ease-out";
    setTimeout(() => toast.remove(), 300);
  }, 2800);
}

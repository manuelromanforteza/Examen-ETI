// Full tournament demo — headed Chromium, visible windows
// Run: node test/e2e/full_tournament_demo.js

const { chromium } = require('@playwright/test');
const path = require('path');
const fs   = require('fs');

const BASE   = 'http://localhost:3000';
const SS_DIR = path.join(__dirname, 'screenshots');
fs.mkdirSync(SS_DIR, { recursive: true });

let ssIndex = 1;
async function shot(page, name) {
  const file = path.join(SS_DIR, `${String(ssIndex++).padStart(2,'0')}_${name}.png`);
  await page.screenshot({ path: file, fullPage: true });
  console.log(`  📸 ${path.basename(file)}`);
}

// Collect JS console errors per page
function watchConsole(page, label) {
  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errors.push(`[${label}] ${msg.text()}`);
    }
  });
  return errors;
}

async function joinAndPick(browser, groupName, pin, strategyName, label) {
  const ctx  = await browser.newContext();
  const page = await ctx.newPage();
  const errs = watchConsole(page, label);

  console.log(`\n[${label}] Joining as "${groupName}"...`);
  await page.goto(`${BASE}/join`);
  await page.fill('input[name="name"]', groupName);
  await page.fill('input[name="pin"]',  pin);
  // Join form uses <input type="submit">
  await page.click('input[name="commit"]');

  // Should land on /strategies
  await page.waitForURL(`${BASE}/strategies`, { timeout: 8000 });
  console.log(`[${label}] At /strategies`);
  await page.waitForTimeout(600);
  await shot(page, `${label}_strategies`);

  // Strategies page: cards are <div> containing <h2> with strategy name
  // and a button_to form with button "Elegir esta estrategia"
  // Find the card whose h2 matches strategyName, then click its button
  const cards = page.locator('div.rounded-2xl');
  const count  = await cards.count();
  let clicked  = false;
  for (let i = 0; i < count; i++) {
    const card = cards.nth(i);
    const h2   = card.locator('h2').first();
    const txt  = await h2.innerText().catch(() => '');
    if (txt.trim() === strategyName) {
      await card.locator('button').first().click();
      clicked = true;
      break;
    }
  }
  if (!clicked) throw new Error(`[${label}] Could not find strategy card for "${strategyName}"`);

  // Wait for /waiting
  await page.waitForURL(`${BASE}/waiting`, { timeout: 8000 });
  console.log(`[${label}] At /waiting — strategy "${strategyName}" picked!`);
  await page.waitForTimeout(600);
  await shot(page, `${label}_waiting`);

  return { page, ctx, errs };
}

(async () => {
  const consoleErrors = [];

  const browser = await chromium.launch({
    headless: false,
    slowMo:   300,
    args:     ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    // ── Step 2: Open admin context ────────────────────────────────────────
    console.log('\n[ADMIN] Opening admin panel...');
    const adminCtx  = await browser.newContext({
      httpCredentials: { username: 'admin', password: 'admin123' }
    });
    const adminPage = await adminCtx.newPage();
    const adminErrs = watchConsole(adminPage, 'ADMIN');
    consoleErrors.push(adminErrs);

    await adminPage.goto(`${BASE}/admin`);
    await adminPage.waitForLoadState('networkidle');
    console.log('[ADMIN] Loaded /admin');
    await shot(adminPage, 'admin_initial');

    // ── Step 2: Groups join and pick strategies ───────────────────────────
    const groups = [
      { name: 'Grupo Test A', pin: '1111', strategy: 'Tit for Tat',     label: 'groupA' },
      { name: 'Grupo Test B', pin: '2222', strategy: 'Tester',           label: 'groupB' },
      { name: 'Grupo Test C', pin: '3333', strategy: 'Joss',             label: 'groupC' },
    ];

    const groupPages = [];
    for (const g of groups) {
      const result = await joinAndPick(browser, g.name, g.pin, g.strategy, g.label);
      groupPages.push({ ...result, label: g.label });
      consoleErrors.push(result.errs);

      // After each pick, reload admin and check counter
      await adminPage.reload();
      await adminPage.waitForLoadState('networkidle');
      const counterText = await adminPage.locator('#ready_counter, [id*="ready"], [id*="counter"]').first().innerText().catch(() => 'N/A');
      console.log(`[ADMIN] Counter after ${g.label}: "${counterText}"`);
      await shot(adminPage, `admin_counter_after_${g.label}`);
    }

    // ── Step 3: Wait for all 3 to show ready ─────────────────────────────
    console.log('\n[ADMIN] Waiting for counter to show 3 / 3...');
    await adminPage.reload();
    await adminPage.waitForLoadState('networkidle');
    await shot(adminPage, 'admin_counter_3_of_3');

    // ── Step 4: Run tournament ────────────────────────────────────────────
    console.log('\n[ADMIN] Running tournament...');
    await adminPage.reload();
    await adminPage.waitForLoadState('networkidle');
    // Wait for the run button to be enabled (not disabled)
    const runBtn = adminPage.locator('button:has-text("Ejecutar"):not([disabled])');
    await runBtn.waitFor({ timeout: 10000 });
    await shot(adminPage, 'admin_before_run');
    await runBtn.click();
    await adminPage.waitForLoadState('networkidle');
    console.log('[ADMIN] Tournament run triggered');
    await shot(adminPage, 'admin_after_run');

    // ── Step 5: Verify groups auto-redirect to /results ───────────────────
    console.log('\n[BROADCAST] Waiting for groups to auto-redirect to /results...');
    const redirectResults = await Promise.allSettled(
      groupPages.map(({ page, label }) =>
        page.waitForURL(`${BASE}/results`, { timeout: 8000 })
          .then(() => ({ label, ok: true }))
          .catch(() => ({ label, ok: false }))
      )
    );

    let allRedirected = true;
    for (const r of redirectResults) {
      const { label, ok } = r.value || r.reason || {};
      if (ok) {
        console.log(`  ✅ ${label} redirected to /results automatically`);
      } else {
        console.log(`  ❌ ${label} DID NOT redirect — Action Cable may not be working!`);
        allRedirected = false;
      }
    }

    if (!allRedirected) {
      console.error('\n⚠️  BROADCAST FAILED: at least one group did not auto-redirect!');
    }

    // ── Step 6: Screenshot /results with leaderboard animation ───────────
    await groupPages[0].page.waitForTimeout(1500); // let animation start
    await shot(groupPages[0].page, 'results_leaderboard_mid_animation');
    await groupPages[0].page.waitForTimeout(3000); // let it finish
    await shot(groupPages[0].page, 'results_leaderboard_final');
    console.log('[groupA] Results leaderboard captured');

    // ── Step 7: My matches / replay ───────────────────────────────────────
    console.log('\n[groupA] Navigating to /my_matches...');
    await groupPages[0].page.goto(`${BASE}/my_matches`);
    await groupPages[0].page.waitForLoadState('networkidle');
    await shot(groupPages[0].page, 'my_matches_list');
    console.log('[groupA] At /my_matches');

    // Click first replay button
    const replayBtn = groupPages[0].page.locator('a:has-text("replay"), a:has-text("Ver replay"), a[href*="my_match"]').first();
    await replayBtn.waitFor({ timeout: 3000 });
    await replayBtn.click();
    await groupPages[0].page.waitForLoadState('networkidle');
    console.log('[groupA] Replay page opened');

    // Screenshot mid-animation
    await groupPages[0].page.waitForTimeout(1500);
    await shot(groupPages[0].page, 'replay_mid_animation');

    // Screenshot after animation completes
    await groupPages[0].page.waitForTimeout(5000);
    await shot(groupPages[0].page, 'replay_complete');

    // ── Step 9: Console errors summary ───────────────────────────────────
    console.log('\n══════════════════════════════════════════════');
    console.log('SUMMARY');
    console.log('══════════════════════════════════════════════');
    console.log(`Action Cable broadcast: ${allRedirected ? '✅ WORKING' : '❌ FAILED'}`);

    const allErrors = consoleErrors.flat();
    if (allErrors.length === 0) {
      console.log('JS Console errors: ✅ None');
    } else {
      console.log(`JS Console errors: ⚠️  ${allErrors.length} error(s) found:`);
      allErrors.forEach(e => console.log('  - ' + e));
    }

    const shots = fs.readdirSync(SS_DIR).filter(f => f.endsWith('.png')).sort();
    console.log(`\nScreenshots (${shots.length}) in test/e2e/screenshots/:`);
    shots.forEach(f => console.log('  ' + f));

    console.log('\n⏸  Leaving browsers open for 30 seconds — check your screen!');
    await groupPages[0].page.waitForTimeout(30000);

  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error('\n💥 FATAL ERROR:', err.message);
  process.exit(1);
});

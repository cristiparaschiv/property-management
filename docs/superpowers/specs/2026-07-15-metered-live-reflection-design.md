# Reflectarea live a calculului pe contor pe ecranul Calcul Utilități

**Data:** 2026-07-15
**Status:** Design aprobat, gata de plan de implementare
**Context anterior:** [2026-04-20-metered-gas-water-billing-design.md](2026-04-20-metered-gas-water-billing-design.md)

## Problemă

Facilitatea de facturare pe contor pentru gaz și apă (introdusă în seria de commit-uri `751e7d9`..`30080ac`) este funcțională în backend (motorul de calcul și PDF-ul), dar experiența pe ecranul **Calcul Utilități** nu reflectă setările de contor și îngreunează introducerea datelor:

1. **Setările nu se reflectă vizual.** Panoul „Procente și Costuri Chiriași" calculează întotdeauna `total_factură × procent / 100` și ignoră complet `uses_meter`, citirile de index și inputurile metered (`frontend/src/pages/UtilityCalculations.jsx:265-309`). Un chiriaș pe contor apare cu procentul fix, nu cu cel calculat din consum.

2. **Câmpul „Cost apă pluvială" este ascuns până la salvarea manuală a calculului.** Blocul „Contori — inputs factură furnizor" (care conține total m³ și valoarea pluvială) se randează doar când `hasExistingCalculation && (needsGas || needsWater)` (`UtilityCalculations.jsx:1114`). Utilizatorul trebuie să apese întâi „Salvează Calcul" ca să apară câmpurile — flux neintuitiv.

3. **Bug de resetare silențioasă a contorului.** Butonul „Salvează %" din cardul fiecărui chiriaș (`UtilityCalculations.jsx:988` → `handleSavePercentages`) trimite procentele ca numere scalare, fără `uses_meter`. Backend-ul, la primirea unei valori scalare, forțează `uses_meter => 0` (`backend/lib/PropertyManager/Routes/Tenants.pm:277-282`), ștergând pe tăcute flag-ul setat în pagina Chiriași.

4. **Câmpul „Cost consum" (apă) se introduce manual**, deși poate fi derivat ca `total_factură − valoare_pluvială`.

## Obiective

- Pe ecranul Calcul Utilități, pentru chiriașii cu `uses_meter=TRUE` pe gaz/apă, reflectarea **live** a calculului pe contor în cardul fiecărui chiriaș, cu consumul tras automat din citirile de index.
- Un bloc de inputuri pe lună (total m³ gaz, total m³ apă, valoare pluvială) **mereu vizibil** când există chiriași pe contor, fără pasul manual de salvare a calculului.
- Derivarea automată a costului de consum apă (`total_factură − valoare_pluvială`).
- Eliminarea bug-ului de resetare a flag-ului `uses_meter`.
- Menținerea sursei unice de adevăr la finalizare (motorul backend rămâne autoritativ).

## Non-obiective

- Fără modificări de schemă DB — toate câmpurile necesare există deja în `metered_calculation_inputs` (`total_units`, `rain_amount`, `consumption_amount`).
- Fără modificări la PDF — pagina 2 („Detalii calcul contori", `backend/templates/pdf/invoice.tt:786-814`) randează deja desfășurarea pe template-ul default, care este cel folosit. Template-urile personalizate rămân în afara scopului (limitare cunoscută).
- Fără modificări la fluxul de finalizare / motorul de calcul de la finalizare (`UtilityCalculator.pm:_resolve_tenant_share`) în afara celor strict necesare pentru derivare.
- Fără generalizarea contoarelor gaz/apă/electricitate într-o abstracție unică.

## Formule (sursa de adevăr)

Notații: `consum` = diferența de index a chiriașului (m³, din `gas_readings`/`water_readings`); `total_m3` = `metered_calculation_inputs.total_units`; `factură` = suma facturii furnizorului pentru utilitatea respectivă.

**Gaz:**
```
procent  = consum / total_m3_gaz × 100
sumă     = (procent / 100) × factură_gaz
```

**Apă:**
```
valoare_apă (consum) = factură_apă − valoare_pluvială
rain_share           = (rain_pct / 100) × valoare_pluvială
consum_share         = (consum / total_m3_apă) × valoare_apă
sumă                 = rain_share + consum_share
procent_efectiv      = sumă / factură_apă × 100
```
unde `rain_pct` = `tenant_utility_percentages.percentage` pentru apă (reinterpretat ca procent apă pluvială când `uses_meter=1`).

Exemplu apă (consum 1.1 m³, total 47 m³, pluvială 779.14 RON, factură 1883.58 RON, rain_pct 20%):
`valoare_apă = 1104.44`; `rain_share = 155.83`; `consum_share = 1.1/47 × 1104.44 = 25.85`; `sumă = 181.67`; `procent_efectiv = 9.6%`.

Aceste formule sunt identice cu motorul backend existent (`UtilityCalculator.pm:309-332`).

## Design

### A. Fix bug „resetare contor" (defense in depth)

**Backend — `Routes/Tenants.pm`, `PUT /:id/percentages`:**
- Când o intrare de procent vine ca **scalar** (nu hashref), în loc de `uses_meter => 0`, se citește valoarea existentă din DB pentru acel `(tenant_id, utility_type)` și se **păstrează**. Dacă nu există rând, `uses_meter => 0` (default). Astfel, salvarea unui procent nu mai poate șterge flag-ul.

**Frontend — `UtilityCalculations.jsx`, cardul chiriașului:**
- Pentru gaz/apă cu `uses_meter=1`, procentul devine **read-only calculat** (afișat cu desfășurare), nu câmp editabil. „Salvează %" trimite doar utilitățile non-metered.
- Rain% (procent apă pluvială) se editează în continuare doar în Chiriași → Procente.

### B. Bloc „Contori (lună)" — mereu vizibil, cu auto-draft

**Vizibilitate:** blocul se randează când `needsGas || needsWater` (se scoate condiția `hasExistingCalculation`).

**Câmpuri:**
- **Gaz** (dacă `needsGas`): select factură furnizor gaz + `Total m³`.
- **Apă** (dacă `needsWater`): select factură furnizor apă + `Total m³` + `Valoare pluvială (RON)`. Sub ele, text read-only: `Valoare apă (consum) = factură − pluvială`. Se elimină câmpul separat „Cost consum".

**Auto-draft:** metered inputs sunt legate de `calculation_id` (FK). La salvarea unui input, dacă nu există calcul pe lună (`existingCalculation` lipsă), frontend-ul creează întâi un draft (`utilityCalculationsService.create` cu overrides din starea curentă), apoi salvează inputul folosind noul `calculation_id`. Crearea draft-ului este lazy (la prima salvare de input), nu la simpla deschidere a lunii, ca să nu se creeze calcule goale pentru fiecare lună răsfoită.

**Backend — `Routes/MeteredCalculationInputs.pm` (apă):** ruta cere `total_units` + `rain_amount`; **derivează** `consumption_amount = received_invoice.amount − rain_amount` și îl persistă (astfel PDF-ul, care citește `consumption_amount` din DB, rămâne consistent). Validarea existentă (`rain_amount` obligatoriu pentru apă) se păstrează; se elimină cerința de a primi `consumption_amount` din client.

### C. Reflectare live în cardul chiriașului

**Date suplimentare aduse pe ecran:** citirile de gaz și apă pe lună (`gasReadingsService.getByPeriod`, `waterReadingsService.getByPeriod`), pentru a obține consumul (diferența de index) per chiriaș.

**Calcul preview:** un modul pur nou `frontend/src/utils/meteredCalc.js` care implementează formulele de mai sus (gaz și apă), primind consum, total m³, valoare pluvială, rain_pct, factură. Modulul oglindește backend-ul și este testabil izolat.

**Afișare în card:**
- Gaz metered: `consum X / total Y → procent% → sumă RON`.
- Apă metered: desfășurare (rain_share, consum_share, sumă, procent efectiv).
- Dacă lipsește total m³ sau citirea chiriașului: se afișează „—" plus un avertisment vizibil, nu un număr greșit.

**Totaluri:** `tenantCosts` și `companyPortions` (`UtilityCalculations.jsx:265-309`) se recalculează incluzând sumele/procentele efective metered, astfel încât totalul chiriașilor și cota proprietarului (`100% − suma chiriașilor`) să fie corecte.

### D. Sursă unică de adevăr

- Motorul autoritativ la finalizare rămâne `UtilityCalculator.pm:_resolve_tenant_share` (deja implementat, identic cu formulele de mai sus). Cu derivarea `consumption_amount` din secțiunea B, comportamentul rămâne neschimbat funcțional.
- Preview-ul frontend (`meteredCalc.js`) reproduce aceleași formule; duplicarea JS↔Perl este documentată și acoperită de teste pe ambele părți.

## Flux de date (chiriaș pe contor, ciclu lunar)

1. Activare contor gaz/apă și setare procent apă pluvială în Chiriași → Procente (păstrat corect după fix-ul A).
2. Introducere facturi primite (gaz, apă) — neschimbat.
3. Introducere citiri index gaz/apă pentru lună — neschimbat.
4. Calcul Utilități, selectare lună: apare blocul „Contori (lună)"; se introduc total m³ gaz, total m³ apă, valoare pluvială. La prima salvare se creează automat draft-ul de calcul.
5. Cardurile chiriașilor pe contor arată live procentul și suma calculate din citiri; totalurile și cota proprietarului se actualizează.
6. Finalizare: motorul backend recalculează autoritativ și scrie `utility_calculation_details`.
7. Generare facturi: PDF-ul afișează pe pagina 2 „Detalii calcul contori" (deja implementat).

## Cazuri limită

- `total_m3 = 0` sau gol → se evită împărțirea la 0; preview afișează „—" + avertisment; finalizarea rămâne blocată cu mesaj clar (comportament existent în `UtilityCalculator.pm:307`).
- `consum = 0` → procent 0 (valid).
- `rain_amount > factură` → `consumption_amount` negativ; avertisment pe ecran, dar se permite salvarea (toleranță la rotunjiri, ca în spec-ul original).
- Chiriaș cu `uses_meter=1` fără citire pe lună → avertisment în card + finalizarea blocată (comportament existent, `UtilityCalculator.pm:299`).

## Testare

- **Backend:** extinderea testelor metered existente (`backend/t/`) pentru derivarea `consumption_amount = factură − rain_amount` la ruta de metered inputs pentru apă; verificarea că gaz/apă produc procentele corecte din citiri.
- **Frontend:** test unitar pentru `meteredCalc.js` (gaz, apă, cazuri limită: total 0, consum 0, rain > factură), folosind exemplul numeric din secțiunea Formule.

## Riscuri și mitigări

- **Duplicare formulă JS↔Perl:** acoperită de teste pe ambele părți cu același exemplu numeric de referință; documentat în `meteredCalc.js`.
- **Auto-draft creează calcule:** creare lazy doar la prima salvare de input; draft-urile ne-finalizate sunt oricum înlocuite la re-salvarea calculului (`Routes/UtilityCalculations.pm:152`).
- **Template-uri personalizate de factură** nu primesc automat blocul PDF — în afara scopului; utilizatorul folosește template-ul default.

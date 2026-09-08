# Runtime QA Matrix

AVD: `KiraRota_Test_Pixel8` / `emulator-5556`

| Check | Status | Detail |
|---|---|---|
| AVD | PASS | KiraRota_Test_Pixel8 / emulator-5556 |
| fresh_launch | PASS | onboarding/splash |
| onboarding_complete | PASS | step=1 |
| tab_Özet | PARTIAL | tap miss |
| nav_Özet | PASS | 20_tab_ozet.png |
| tab_Kiralarım | PARTIAL | tap miss |
| nav_Kiralarım | PASS | 21_tab_kiralarim.png |
| tab_Hesapla | PASS | opened |
| nav_Hesapla | PASS | 22_tab_hesapla.png |
| tab_Oranlar | PARTIAL | tap miss |
| nav_Oranlar | PASS | 23_tab_oranlar.png |
| tab_Ayarlar | PARTIAL | tap miss |
| nav_Ayarlar | PASS | 24_tab_ayarlar.png |
| tab_Kiralarım | PARTIAL | tap miss |
| rental_add_name | PARTIAL | no EditText |
| rental_create_minimal | FAIL | save not tapped |
| tab_Özet | PARTIAL | tap miss |
| tab_Hesapla | PASS | opened |
| calculate_official | PASS | result visible |
| tab_Ayarlar | PARTIAL | tap miss |
| paywall_open | PARTIAL | entry not found |
| back_from_paywall | FAIL | unexpected UI |
| tab_Kiralarım | PARTIAL | tap miss |
| free_rental_limit_gate | PARTIAL | unclear |
| tab_Hesapla | PASS | opened |
| keyboard_open | PARTIAL | no EditText |
| persistence_after_force_stop | FAIL | unexpected empty/crash |
| background_foreground | PASS | restored |
| rapid_nav_stress | PASS | stable |
| offline_startup | PASS | app usable |
| tab_Oranlar | PARTIAL | tap miss |
| offline_rates_fallback | PASS | rates visible |
| tab_Hesapla | PASS | opened |
| tab_Özet | PARTIAL | tap miss |
| font_scale_150 | PASS | screenshots captured |
| logcat_fatal_anr | PASS | 0 FATAL / 0 ANR |
| logcat_app_exceptions | PARTIAL | 2 lines (see logcat_audit.json) |

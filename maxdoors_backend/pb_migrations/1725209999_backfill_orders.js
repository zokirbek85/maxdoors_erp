/// <reference path="../pb_data/types.d.ts" />

// JS migratsiya sandboxida Dao/db.prepare mavjud bo'lmagan buildlarda xatoni oldini olish uchun
// bu migratsiyani "no-op" qilamiz. Backfill alohida Node skript bilan bajariladi.

migrate((db) => {
  // UP: hech narsa qilmaymiz
}, (db) => {
  // DOWN: hech narsa
});

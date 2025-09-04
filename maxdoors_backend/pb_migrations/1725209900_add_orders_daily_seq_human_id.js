/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
  // UP: daily_seq, human_id ustunlarini qo‘shishga urinamiz
  try { db.prepare("ALTER TABLE orders ADD COLUMN daily_seq INTEGER").run() } catch (_) {}
  try { db.prepare("ALTER TABLE orders ADD COLUMN human_id  TEXT").run()    } catch (_) {}
}, (db) => {
  // DOWN: SQLite DROP COLUMN yo‘qligi sabab, rollback sifatida qiymatlarni NULL qilamiz
  try {
    db.prepare("UPDATE orders SET daily_seq=NULL, human_id=NULL").run()
  } catch (_) {}
});

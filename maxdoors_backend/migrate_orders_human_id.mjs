/**
 * Backfill for orders.daily_seq and orders.human_id via PocketBase REST
 *
 * ENV:
 *   PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD
 *
 * Usage:
 *   node migrate_orders_human_id.js [--force] [--dry] [--by=warehouse]
 *   --force  : mavjud human_id/daily_seq bo'lsa ham qayta yozadi
 *   --dry    : faqat konsolga chiqaradi, yozmaydi
 *   --by=... : kundalik sanashni shu field bo'yicha guruhlaydi (mas. warehouse)
 */

import PocketBase from 'pocketbase';

const { PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD } = process.env;
if (!PB_URL || !PB_ADMIN_EMAIL || !PB_ADMIN_PASSWORD) {
  console.error('Missing ENV. Set PB_URL, PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD');
  process.exit(1);
}

const FORCE = process.argv.includes('--force');
const DRY   = process.argv.includes('--dry');
const byArg = process.argv.find(a => a.startsWith('--by='));
const GROUP_BY = byArg ? byArg.split('=')[1] : null;

const ymd = d => d.toISOString().slice(0, 10);
const fmtHuman = (seq, date) => {
  const dd = String(date.getDate()).padStart(2, '0');
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const yyyy = String(date.getFullYear());
  const nnn = String(seq).padStart(3, '0');
  return `${nnn}-${dd}.${mm}.${yyyy}`;
};

async function main() {
  const pb = new PocketBase(PB_URL);
  await pb.admins.authWithPassword(PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD);
  console.log('✅ Admin authenticated');

  const fields = ['id','created','human_id','daily_seq'];
  if (GROUP_BY) fields.push(GROUP_BY);

  const perPage = 200;
  let page = 1;
  const all = [];

  console.log('📥 Fetching orders...');
  while (true) {
    const list = await pb.collection('orders').getList(page, perPage, {
      sort: 'created',                 // eng eski birinchi
      fields: fields.join(','),        // minimal maydonlar
    });
    all.push(...list.items);
    if (page * perPage >= list.totalItems) break;
    page++;
  }
  console.log(`Found ${all.length} orders.`);

  // Kundalik (va ixtiyoriy GROUP_BY bo'yicha) hisoblagich
  // key: `${YYYY-MM-DD}__${groupVal}`
  const counters = new Map();

  let updated = 0, skipped = 0;

  for (const o of all) {
    const created = new Date(o.created);
    const keyDate = ymd(created);
    const groupVal = GROUP_BY ? (o[GROUP_BY] || '-') : '-';
    const counterKey = `${keyDate}__${groupVal}`;

    const already = !!o.human_id && o.daily_seq != null;
    if (already && !FORCE) { skipped++; continue; }

    const next = (counters.get(counterKey) || 0) + 1;
    counters.set(counterKey, next);

    const human = fmtHuman(next, created);

    if (DRY) {
      console.log(`[DRY] ${o.id} -> daily_seq=${next}, human_id=${human}`);
      updated++;
      continue;
    }

    await pb.collection('orders').update(o.id, {
      daily_seq: next,
      human_id: human,
    });

    updated++;
    if (updated % 200 === 0) console.log(`...updated ${updated}`);
  }

  console.log(`\n✅ Done. Updated: ${updated}, Skipped: ${skipped}, Grouped by: ${GROUP_BY || 'none'}.`);
}

main().catch((e) => {
  console.error('Migration error:', e);
  process.exit(1);
});

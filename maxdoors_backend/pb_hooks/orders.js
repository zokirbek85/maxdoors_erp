/// <reference path="../pb_data/types.d.ts" />

// Buyurtmaga kunlik tartib raqam (NNN-dd.MM.yyyy) berish.
// Stokni kamaytirish endi order_items hooklarida real-vaqtda qilinadi.
// Bu faylda esa: beforeCreate — human_id/daily_seq, afterDelete — zaxirani qaytarish (safety).

module.exports = ({ pb }) => {
  // === Helperlar ===
  function startOfDayUtc(d) {
    const dt = new Date(d);
    return new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate(), 0, 0, 0));
  }
  function addDays(d, days) {
    const dt = new Date(d);
    dt.setUTCDate(dt.getUTCDate() + days);
    return dt;
  }
  function fmtHuman(seq, dateOrIso) {
    const d = new Date(dateOrIso);
    const dd = String(d.getUTCDate()).padStart(2, '0');
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    const yyyy = String(d.getUTCFullYear());
    const nnn = String(seq).padStart(3, '0');
    return `${nnn}-${dd}.${mm}.${yyyy}`;
  }

  async function nextDailySeq({ createdIso, groupByField = null, groupByValue = null }) {
    const dayStart = startOfDayUtc(createdIso);
    const dayEnd = addDays(dayStart, 1); // [dayStart, dayEnd)

    let filter = `created >= "${dayStart.toISOString()}" && created < "${dayEnd.toISOString()}"`;
    if (groupByField && groupByValue) {
      filter += ` && ${groupByField} = "${groupByValue}"`;
    }

    const list = await pb.collection('orders').getList(1, 1, {
      filter,
      sort: '-created',
      fields: 'id',
    });

    return (list.totalItems || 0) + 1;
  }

  // === beforeCreate: status/discount defaultlari va human_id/daily_seq tayinlash ===
  pb.collection('orders').beforeCreate(async (req, res) => {
    const data = req.data || {};

    data.status = data.status || 'created';
    if (data.discount_type == null && data.discountType == null) {
      data.discount_type = 'none';
    }

    const createdIso = data.created || new Date().toISOString();

    // Agar ombor kesimida numeratsiya kerak bo'lsa:
    // const groupField = 'warehouse';
    // const groupVal   = data[groupField] || null;
    const groupField = null;
    const groupVal = null;

    const seq = await nextDailySeq({
      createdIso,
      groupByField: groupField,
      groupByValue: groupVal,
    });

    data.daily_seq = seq;
    data.human_id = fmtHuman(seq, createdIso);

    req.data = data;
  });

  // === afterUpdate: (ESKI) packed'da stock kamaytirish — OLIB TASHLANDI ===
  pb.collection('orders').afterUpdate(async (req, res) => {
    // endi hech narsa qilmaymiz — real-vaqt stok hisoblash order_items hooklarida.
  });

  // === afterDelete: buyurtma o‘chirilib ketsa, itemlari bo‘yicha zaxirani qaytarib qo‘yish (safety) ===
  pb.collection('orders').afterDelete(async (req, res) => {
    try {
      const order = req.record;
      if (!order) return;

      // Buyurtmaning barcha itemlarini topamiz
      const items = await pb.collection('order_items').getFullList({
        filter: `order = "${order.id}"`,
      });

      // Har bir item bo‘yicha zaxirani qaytarish
      for (const it of items) {
        const qty = Number(it.qty || 0);
        if (!Number.isFinite(qty) || qty <= 0) continue;

        try {
          const p = await pb.collection('products').getOne(it.product);
          const currOk = Number(p.stock_ok ?? p.stock ?? 0);
          await pb.collection('products').update(p.id, { stock_ok: currOk + qty });
        } catch (e) {
          console.error('[orders.afterDelete] return stock error:', e);
        }
      }
    } catch (e) {
      console.error('[orders.afterDelete] error:', e);
    }
  });
};

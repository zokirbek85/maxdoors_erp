/// <reference path="../pb_data/types.d.ts" />

/**
 * order_items o'zgarganda zaxirani sinxron yuritish:
 *  - afterCreate: qty > 0 bo‘lsa zaxiradan kamaytiradi
 *  - afterUpdate: qty farqi bo‘yicha zaxirani o‘zgartiradi
 *  - afterDelete: qty miqdorida zaxirani qaytaradi
 *
 * Eslatma:
 *  - faqat status = created | editable bo‘lganda ishlaydi (aktiv holat)
 *    agar sizda boshqa qoidalar bo‘lsa, pastdagi isActiveStatus() ni moslang.
 */

module.exports = ({ pb }) => {
  // Parent order'ni o‘qish
  async function readOrder(orderId) {
    try {
      return await pb.collection('orders').getOne(orderId);
    } catch (_) {
      return null;
    }
  }

  function isActiveStatus(st) {
    const s = String(st || '').toLowerCase();
    return s === 'created' || s === 'editable';
  }

  async function changeProductStock(productId, delta) {
    if (!productId || !Number.isFinite(delta) || delta === 0) return;

    const p = await pb.collection('products').getOne(productId);
    const currOk = Number(p.stock_ok ?? p.stock ?? 0);
    const nextOk = currOk + Number(delta); // delta manfiy bo‘lsa kamayadi, musbat bo‘lsa ortadi

    await pb.collection('products').update(productId, {
      stock_ok: nextOk,
    });
  }

  // --- CREATE ---
  pb.collection('order_items').afterCreate(async (req, res) => {
    const it = req.record;              // yangi item
    const qty = Number(it.qty || 0);
    if (!Number.isFinite(qty) || qty <= 0) return;

    const order = await readOrder(it.order);
    if (!order || !isActiveStatus(order.status)) return;

    // Yangi item qo‘shildi → zaxiradan kamaytirish
    await changeProductStock(it.product, -qty);
  });

  // --- UPDATE ---
  pb.collection('order_items').afterUpdate(async (req, res) => {
    // Ba'zi PB versiyalarida prev yozuvga req.record.getOriginal() bilan ham kirish mumkin;
    // yo‘q bo‘lsa, req.prevRecord yoki req.data.prev ishlatiladi (fallback sifatida bosqichma-bosqich).
    let prevQty = 0;
    try { prevQty = Number(req.record?.getOriginal?.().qty ?? 0); } catch (_) {}
    if (!prevQty) {
      try { prevQty = Number(req.prevRecord?.qty ?? 0); } catch (_) {}
    }
    if (!prevQty) {
      try { prevQty = Number((req?.data?.prev ?? {}).qty ?? 0); } catch (_) {}
    }

    const curr = req.record;
    const currQty = Number(curr.qty || 0);
    if (!Number.isFinite(currQty)) return;

    const diff = currQty - prevQty; // >0 bo‘lsa qo‘shimcha kamaytirish; <0 bo‘lsa qaytarish
    if (diff === 0) return;

    const order = await readOrder(curr.order);
    if (!order || !isActiveStatus(order.status)) return;

    await changeProductStock(curr.product, -diff);
  });

  // --- DELETE ---
  pb.collection('order_items').afterDelete(async (req, res) => {
    const it = req.record;            // o‘chirilgan item snapshot
    const qty = Number(it.qty || 0);
    if (!Number.isFinite(qty) || qty <= 0) return;

    const order = await readOrder(it.order);
    if (!order || !isActiveStatus(order.status)) return;

    // O‘chirish → zaxirani qaytarish
    await changeProductStock(it.product, +qty);
  });
};

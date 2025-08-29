const { applyStockDelta, updateAvgCostOnPurchase } = require('./lib/stock');

module.exports = ({ pb }) => {
  pb.collection('stock_entry_items').afterCreate(async (req, res) => {
    const it = req.record;
    const qty = Number(it.qty || 0);
    const price = Number(it.price || 0);

    const entry = await pb.collection('stock_entries').getOne(it.entry);
    const currency = entry.currency;
    const rate = Number(entry.rate || 0);

    let unitCostUsd = price;
    if (currency === 'UZS') {
      if (!rate) throw new Error('Kirimda kurs kerak');
      unitCostUsd = price / rate;
    }

    await applyStockDelta({
      pb,
      productId: it.product,
      deltaOk: it.is_defect ? 0 : qty,
      deltaDefect: it.is_defect ? qty : 0,
      reason: 'purchase',
      refId: it.entry,
    });

    if (!it.is_defect) {
      await updateAvgCostOnPurchase({ pb, productId: it.product, qty, unitCostUsd });
    }
  });
};

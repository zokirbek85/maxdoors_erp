const { applyStockDelta } = require('./lib/stock');

module.exports = ({ pb }) => {
  pb.collection('return_entry_items').afterCreate(async (req, res) => {
    const it = req.record;
    const qty = Number(it.qty || 0);
    await applyStockDelta({
      pb,
      productId: it.product,
      deltaOk: it.is_defect ? 0 : qty,
      deltaDefect: it.is_defect ? qty : 0,
      reason: 'return_in',
      refId: it.entry,
    });
  });
};

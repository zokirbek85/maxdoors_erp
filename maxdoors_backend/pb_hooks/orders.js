const { makeOrderHumanId } = require('./lib/ids');
const { applyStockDelta } = require('./lib/stock');

module.exports = ({ pb }) => {
  pb.collection('orders').beforeCreate(async (req, res) => {
    req.data.status = req.data.status || 'created';
    req.data.discount_type = req.data.discount_type || 'none';
    req.data.editable = false;

    const { human, dailySeq } = await makeOrderHumanId({ pb });
    req.data.human_id = human;
    req.data.daily_seq = dailySeq;
  });

  pb.collection('orders').afterUpdate(async (req, res) => {
    const curr = req.record;
    if (curr.status === 'packed') {
      const items = await pb.collection('order_items').getFullList({
        filter: `order = "${curr.id}"`,
      });
      for (const it of items) {
        const p = await pb.collection('products').getOne(it.product);
        await applyStockDelta({
          pb,
          productId: it.product,
          deltaOk: -Number(it.qty || 0),
          deltaDefect: 0,
          reason: 'order_pack',
          refId: curr.id,
        });
        const cost = p.avg_cost_usd || 0;
        await pb.collection('order_items').update(it.id, { cogs_usd_snapshot: cost });
      }
    }
  });
};

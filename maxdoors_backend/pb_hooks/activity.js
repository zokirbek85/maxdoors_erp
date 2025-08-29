module.exports = ({ pb }) => {
  const log = async (userId, action, entity, entity_id, payload) => {
    await pb.collection('activity_log').create({
      ts: new Date().toISOString(),
      user: userId,
      action,
      entity,
      entity_id,
      payload,
    });
  };

  for (const col of [
    'products',
    'stock_entries',
    'stock_entry_items',
    'orders',
    'order_items',
    'payments',
    'fx_rates',
  ]) {
    pb.collection(col).afterCreate(async (req, res) => {
      await log(req?.auth?.id, 'create', col, req.record.id, req.record);
    });
    pb.collection(col).afterUpdate(async (req, res) => {
      await log(req?.auth?.id, 'update', col, req.record.id, {
        before: req?.recordBefore,
        after: req.record,
      });
    });
    pb.collection(col).afterDelete(async (req, res) => {
      await log(req?.auth?.id, 'delete', col, req.record?.id, req.record);
    });
  }
};

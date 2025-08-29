module.exports = ({ pb }) => {
pb.collection('dealer_balance_adjustments').afterCreate(async (req, res) => {
// Log adjustment for audit
await pb.collection('activity_log').create({
ts: new Date().toISOString(),
user: req?.auth?.id,
action: 'balance_adjust',
entity: 'dealer',
entity_id: req.record.dealer,
payload: req.record
});
});
};
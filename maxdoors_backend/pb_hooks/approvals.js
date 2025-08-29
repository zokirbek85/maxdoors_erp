module.exports = ({ pb }) => {
  pb.collection('order_edit_requests').beforeCreate(async (req, res) => {
    req.data.status = 'requested';
  });

  pb.collection('order_edit_requests').afterUpdate(async (req, res) => {
    const r = req.record;
    if (r.status === 'approved' && r.approved_by && r.approved_at) {
      await pb.collection('orders').update(r.order, {
        status: 'edit_requested',
        editable: true,
      });
    }
  });
};

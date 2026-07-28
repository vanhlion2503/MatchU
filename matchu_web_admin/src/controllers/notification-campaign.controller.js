const {
  getCampaignStatistics,
  listCampaigns,
  createCampaign,
  getCampaign,
  updateCampaign,
  cancelCampaign,
  retryFailedJobs,
  campaignToForm,
  estimateAudience
} = require('../services/notification-campaign.service');
const { listUsers } = require('../services/user-account.service');
const {
  validateCampaign,
  validateListQuery,
  validateCampaignAction
} = require('../validators/notification-campaign.validator');
const { writeAuditLog } = require('../services/audit-log.service');
const AppError = require('../utils/app-error');

const CATEGORY_LABELS = Object.freeze({
  general: 'Thông báo hệ thống',
  maintenance: 'Thông báo bảo trì',
  app_update: 'Cập nhật phiên bản',
  policy_update: 'Chính sách mới'
});
const AUDIENCE_LABELS = Object.freeze({
  all: 'Toàn hệ thống',
  segment: 'Nhóm người dùng',
  single_user: 'Một người dùng'
});
const STATUS_LABELS = Object.freeze({
  draft: 'Bản nháp',
  scheduled: 'Đã lên lịch',
  queued: 'Đang chờ',
  preparing: 'Đang chuẩn bị',
  sending: 'Đang gửi',
  completed: 'Hoàn tất',
  partial_failed: 'Hoàn tất một phần',
  failed: 'Thất bại',
  cancelled: 'Đã hủy'
});

function formatDate(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh'
  }).format(value);
}

function redirectWithMessage(path, kind, message) {
  const joiner = path.includes('?') ? '&' : '?';
  return `${path}${joiner}${kind}=${encodeURIComponent(message)}`;
}

function flashFromQuery(query) {
  return {
    successMessage: String(query.success || '').slice(0, 300) || null,
    errorMessage: String(query.error || '').slice(0, 300) || null
  };
}

async function index(req, res) {
  const { error, value: filters } = validateListQuery(req.query);
  if (error) throw new AppError('Bộ lọc chiến dịch không hợp lệ.', 400);
  const [campaigns, statistics] = await Promise.all([
    listCampaigns(filters),
    getCampaignStatistics()
  ]);
  return res.render('notifications/index', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Quản lý thông báo',
    campaigns,
    statistics,
    filters,
    categoryLabels: CATEGORY_LABELS,
    audienceLabels: AUDIENCE_LABELS,
    statusLabels: STATUS_LABELS,
    formatDate,
    ...flashFromQuery(req.query)
  });
}

function emptyForm() {
  return {
    revision: 0,
    category: 'general',
    title: '',
    body: '',
    audienceType: 'all',
    targetUserId: '',
    accountStatuses: [],
    genders: [],
    platforms: [],
    verification: '',
    activityDays: '',
    minAge: '',
    maxAge: '',
    minReputation: '',
    maxReputation: '',
    minAppVersion: '',
    maxAppVersion: '',
    interestTags: '',
    channelPush: true,
    channelInbox: true,
    sendMode: 'immediate',
    scheduledAtLocal: '',
    actionType: 'inbox',
    actionValue: ''
  };
}

function renderForm(res, { campaign = null, form, errorMessage = null }) {
  return res.status(errorMessage ? 400 : 200).render('notifications/form', {
    layout: 'layouts/admin-layout',
    pageTitle: campaign ? 'Chỉnh sửa chiến dịch' : 'Tạo thông báo',
    campaign,
    form,
    categoryLabels: CATEGORY_LABELS,
    audienceLabels: AUDIENCE_LABELS,
    errorMessage
  });
}

async function create(req, res) {
  return renderForm(res, { form: emptyForm() });
}

async function searchUsers(req, res) {
  const query = String(req.query.q || '').trim();
  if (query.length < 2) return res.json({ users: [] });
  const result = await listUsers({
    q: query,
    status: '',
    verification: '',
    activity: '',
    risk: '',
    cursor: '',
    limit: 10
  });
  return res.json({
    users: result.users.map((user) => ({
      uid: user.uid,
      displayName: user.fullname || user.nickname || 'Chưa cập nhật tên',
      email: user.email
    }))
  });
}

async function audienceEstimate(req, res) {
  const { error, value } = validateCampaign({
    ...req.body,
    intent: 'save_draft'
  });
  if (error) return res.status(400).json({ success: false, message: error.message });
  const estimate = await estimateAudience(value);
  return res.json({ success: true, ...estimate });
}

async function store(req, res) {
  const { error, value } = validateCampaign(req.body);
  if (error) {
    return renderForm(res, {
      form: { ...emptyForm(), ...req.body },
      errorMessage: error.message
    });
  }
  const id = await createCampaign(value, req.admin);
  await writeAuditLog({
    admin: req.admin,
    action: value.intent === 'publish' ? 'NOTIFICATION_PUBLISHED' : 'NOTIFICATION_DRAFT_CREATED',
    targetType: 'notification_campaign',
    targetId: id,
    metadata: {
      category: value.category,
      audienceType: value.audienceType,
      sendMode: value.sendMode,
      channels: [value.channelPush && 'push', value.channelInbox && 'inbox'].filter(Boolean)
    },
    req
  });
  const message = value.intent === 'publish'
    ? (value.sendMode === 'scheduled' ? 'Đã lên lịch gửi thông báo.' : 'Thông báo đã được đưa vào hàng đợi gửi.')
    : 'Đã lưu bản nháp.';
  return res.redirect(redirectWithMessage(`/notifications/${id}`, 'success', message));
}

async function show(req, res) {
  const campaign = await getCampaign(req.params.campaignId);
  return res.render('notifications/show', {
    layout: 'layouts/admin-layout',
    pageTitle: 'Chi tiết chiến dịch',
    campaign,
    categoryLabels: CATEGORY_LABELS,
    audienceLabels: AUDIENCE_LABELS,
    statusLabels: STATUS_LABELS,
    formatDate,
    ...flashFromQuery(req.query)
  });
}

async function edit(req, res) {
  const campaign = await getCampaign(req.params.campaignId);
  if (!['draft', 'scheduled'].includes(campaign.status)) {
    return res.redirect(redirectWithMessage(
      `/notifications/${campaign.id}`,
      'error',
      'Chiến dịch đã bắt đầu xử lý và không thể chỉnh sửa.'
    ));
  }
  return renderForm(res, { campaign, form: campaignToForm(campaign) });
}

async function update(req, res) {
  const campaign = await getCampaign(req.params.campaignId);
  const { error, value } = validateCampaign(req.body);
  if (error) {
    return renderForm(res, {
      campaign,
      form: { ...campaignToForm(campaign), ...req.body },
      errorMessage: error.message
    });
  }
  await updateCampaign(campaign.id, value, req.admin);
  await writeAuditLog({
    admin: req.admin,
    action: value.intent === 'publish' ? 'NOTIFICATION_PUBLISHED' : 'NOTIFICATION_DRAFT_UPDATED',
    targetType: 'notification_campaign',
    targetId: campaign.id,
    metadata: {
      previousStatus: campaign.status,
      audienceType: value.audienceType,
      sendMode: value.sendMode
    },
    req
  });
  return res.redirect(redirectWithMessage(
    `/notifications/${campaign.id}`,
    'success',
    value.intent === 'publish' ? 'Đã phát hành chiến dịch.' : 'Đã cập nhật bản nháp.'
  ));
}

async function action(req, res) {
  const { error, value } = validateCampaignAction(req.body);
  if (error) throw new AppError('Thao tác chiến dịch không hợp lệ.', 400);
  let message;
  if (value.action === 'cancel') {
    await cancelCampaign(req.params.campaignId, req.admin);
    message = 'Đã hủy phần chiến dịch chưa gửi.';
  } else {
    const count = await retryFailedJobs(req.params.campaignId, req.admin);
    message = `Đã đưa ${count} lô thất bại vào hàng đợi thử lại.`;
  }
  await writeAuditLog({
    admin: req.admin,
    action: `NOTIFICATION_${value.action.toUpperCase()}`,
    targetType: 'notification_campaign',
    targetId: req.params.campaignId,
    metadata: {},
    req
  });
  return res.redirect(redirectWithMessage(
    `/notifications/${req.params.campaignId}`,
    'success',
    message
  ));
}

module.exports = {
  index,
  create,
  searchUsers,
  audienceEstimate,
  store,
  show,
  edit,
  update,
  action
};

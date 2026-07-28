(() => {
  const canvas = document.getElementById('activityChart');
  const dataElement = document.getElementById('dashboardChartData');
  const emptyState = document.getElementById('activityChartEmpty');
  if (!canvas || !dataElement) return;

  let chartData;
  try {
    chartData = JSON.parse(dataElement.textContent || '{}');
  } catch (_) {
    emptyState.hidden = false;
    canvas.hidden = true;
    return;
  }

  const points = Array.isArray(chartData.series) ? chartData.series : [];
  const seriesConfig = {
    users: { label: 'Người dùng mới', color: '#536ae5' },
    posts: { label: 'Bài viết', color: '#21a269' },
    matches: { label: 'Kết nối', color: '#11a5bb' },
    reports: { label: 'Báo cáo', color: '#e15b65' }
  };
  const activeSeries = new Set(['users', 'posts', 'matches']);
  const context = canvas.getContext('2d');
  let hoverIndex = null;
  let layout = null;

  function roundRect(ctx, x, y, width, height, radius) {
    const boundedRadius = Math.min(radius, width / 2, height / 2);
    if (typeof ctx.roundRect === 'function') {
      ctx.beginPath();
      ctx.roundRect(x, y, width, height, boundedRadius);
      return;
    }
    ctx.beginPath();
    ctx.moveTo(x + boundedRadius, y);
    ctx.lineTo(x + width - boundedRadius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + boundedRadius);
    ctx.lineTo(x + width, y + height - boundedRadius);
    ctx.quadraticCurveTo(
      x + width,
      y + height,
      x + width - boundedRadius,
      y + height
    );
    ctx.lineTo(x + boundedRadius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - boundedRadius);
    ctx.lineTo(x, y + boundedRadius);
    ctx.quadraticCurveTo(x, y, x + boundedRadius, y);
    ctx.closePath();
  }

  function draw() {
    const bounds = canvas.getBoundingClientRect();
    const ratio = Math.max(1, window.devicePixelRatio || 1);
    const width = Math.max(320, Math.floor(bounds.width));
    const height = Math.max(220, Math.floor(bounds.height));
    canvas.width = width * ratio;
    canvas.height = height * ratio;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);

    const visibleSeries = [...activeSeries];
    const hasData = points.some((point) => (
      visibleSeries.some((key) => Number(point[key]) > 0)
    ));
    emptyState.hidden = hasData;
    canvas.style.opacity = hasData ? '1' : '.18';

    const padding = { top: 18, right: 16, bottom: 31, left: 34 };
    const plotWidth = width - padding.left - padding.right;
    const plotHeight = height - padding.top - padding.bottom;
    const maxValue = Math.max(
      1,
      ...points.flatMap((point) => visibleSeries.map((key) => Number(point[key]) || 0))
    );
    const roundedMax = Math.ceil(maxValue / 4) * 4 || 4;
    const xStep = points.length > 1 ? plotWidth / (points.length - 1) : plotWidth;

    context.font = '10px system-ui, sans-serif';
    context.textBaseline = 'middle';
    context.lineWidth = 1;
    for (let line = 0; line <= 4; line += 1) {
      const y = padding.top + ((plotHeight / 4) * line);
      context.strokeStyle = '#edf0f5';
      context.beginPath();
      context.moveTo(padding.left, y);
      context.lineTo(width - padding.right, y);
      context.stroke();
      context.fillStyle = '#9aa4b4';
      context.textAlign = 'right';
      context.fillText(String(Math.round(roundedMax * (1 - (line / 4)))), padding.left - 8, y);
    }

    const labelEvery = Math.max(1, Math.ceil(points.length / 7));
    points.forEach((point, index) => {
      if (index % labelEvery !== 0 && index !== points.length - 1) return;
      const x = padding.left + (xStep * index);
      context.fillStyle = '#9aa4b4';
      context.textAlign = index === 0 ? 'left' : index === points.length - 1 ? 'right' : 'center';
      context.fillText(point.label || '', x, height - 10);
    });

    visibleSeries.forEach((key) => {
      const config = seriesConfig[key];
      const coordinates = points.map((point, index) => ({
        x: padding.left + (xStep * index),
        y: padding.top + plotHeight - (((Number(point[key]) || 0) / roundedMax) * plotHeight)
      }));
      if (!coordinates.length) return;

      const gradient = context.createLinearGradient(0, padding.top, 0, padding.top + plotHeight);
      gradient.addColorStop(0, `${config.color}22`);
      gradient.addColorStop(1, `${config.color}00`);
      context.beginPath();
      context.moveTo(coordinates[0].x, padding.top + plotHeight);
      coordinates.forEach((coordinate) => context.lineTo(coordinate.x, coordinate.y));
      context.lineTo(coordinates[coordinates.length - 1].x, padding.top + plotHeight);
      context.closePath();
      context.fillStyle = gradient;
      context.fill();

      context.beginPath();
      coordinates.forEach((coordinate, index) => {
        if (index === 0) context.moveTo(coordinate.x, coordinate.y);
        else context.lineTo(coordinate.x, coordinate.y);
      });
      context.strokeStyle = config.color;
      context.lineWidth = 2;
      context.lineJoin = 'round';
      context.lineCap = 'round';
      context.stroke();
    });

    layout = { padding, plotWidth, plotHeight, xStep, width, height };
    if (hoverIndex == null || !points[hoverIndex]) return;

    const x = padding.left + (xStep * hoverIndex);
    context.strokeStyle = '#b8c1d0';
    context.setLineDash([3, 3]);
    context.beginPath();
    context.moveTo(x, padding.top);
    context.lineTo(x, padding.top + plotHeight);
    context.stroke();
    context.setLineDash([]);

    const entries = visibleSeries.map((key) => ({
      ...seriesConfig[key],
      value: Number(points[hoverIndex][key]) || 0
    }));
    const tooltipWidth = 142;
    const tooltipHeight = 30 + (entries.length * 18);
    const tooltipX = Math.min(width - tooltipWidth - 4, Math.max(4, x + 10));
    const tooltipY = padding.top + 5;
    roundRect(context, tooltipX, tooltipY, tooltipWidth, tooltipHeight, 8);
    context.fillStyle = '#182641';
    context.fill();
    context.fillStyle = '#fff';
    context.font = '700 10px system-ui, sans-serif';
    context.textAlign = 'left';
    context.fillText(points[hoverIndex].label || '', tooltipX + 10, tooltipY + 14);
    entries.forEach((entry, index) => {
      const y = tooltipY + 34 + (index * 18);
      context.fillStyle = entry.color;
      context.beginPath();
      context.arc(tooltipX + 12, y, 3, 0, Math.PI * 2);
      context.fill();
      context.fillStyle = '#dce2ee';
      context.font = '10px system-ui, sans-serif';
      context.fillText(entry.label, tooltipX + 21, y);
      context.fillStyle = '#fff';
      context.textAlign = 'right';
      context.fillText(entry.value.toLocaleString('vi-VN'), tooltipX + tooltipWidth - 10, y);
      context.textAlign = 'left';
    });
  }

  document.querySelectorAll('[data-series-toggle]').forEach((button) => {
    button.addEventListener('click', () => {
      const key = button.dataset.seriesToggle;
      if (!seriesConfig[key]) return;
      if (activeSeries.has(key) && activeSeries.size > 1) {
        activeSeries.delete(key);
        button.classList.remove('active');
        button.setAttribute('aria-pressed', 'false');
      } else {
        activeSeries.add(key);
        button.classList.add('active');
        button.setAttribute('aria-pressed', 'true');
      }
      draw();
    });
  });

  canvas.addEventListener('mousemove', (event) => {
    if (!layout || points.length < 1) return;
    const bounds = canvas.getBoundingClientRect();
    const relativeX = event.clientX - bounds.left - layout.padding.left;
    const nextIndex = points.length === 1
      ? 0
      : Math.round(relativeX / layout.xStep);
    hoverIndex = Math.max(0, Math.min(points.length - 1, nextIndex));
    draw();
  });
  canvas.addEventListener('mouseleave', () => {
    hoverIndex = null;
    draw();
  });

  let resizeFrame = null;
  window.addEventListener('resize', () => {
    if (resizeFrame) window.cancelAnimationFrame(resizeFrame);
    resizeFrame = window.requestAnimationFrame(draw);
  });
  draw();
})();

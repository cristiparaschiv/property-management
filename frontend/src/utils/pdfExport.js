import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { formatCurrency, formatDate } from './formatters';
import { registerRobotoFont } from './pdfFonts';

/**
 * PDF Export utility for Reports
 */

const PDF_CONFIG = {
  pageWidth: 210, // A4 width in mm
  pageHeight: 297, // A4 height in mm
  margin: 15,
  headerHeight: 40,
  footerHeight: 15,
  fontFamily: 'Roboto', // Use Roboto for Romanian character support
  colors: {
    primary: [59, 130, 246], // Blue
    success: [34, 197, 94], // Green
    warning: [234, 179, 8], // Yellow
    error: [239, 68, 68], // Red
    text: [51, 65, 85],
    textLight: [100, 116, 139],
    border: [226, 232, 240],
  },
};

/**
 * Initialize PDF document with custom font
 */
const initPdfDoc = async () => {
  const doc = new jsPDF();
  const fontLoaded = await registerRobotoFont(doc);
  if (fontLoaded) {
    doc.setFont('Roboto', 'normal');
  }
  return { doc, fontFamily: fontLoaded ? 'Roboto' : 'helvetica' };
};

/**
 * Create PDF header with logo and title
 */
const addHeader = (doc, title, subtitle = '', fontFamily = 'Roboto') => {
  const { margin, colors } = PDF_CONFIG;

  // Title
  doc.setFontSize(20);
  doc.setTextColor(...colors.text);
  doc.setFont(fontFamily, 'bold');
  doc.text('Domistra', margin, margin + 8);

  // Subtitle
  doc.setFontSize(14);
  doc.setFont(fontFamily, 'normal');
  doc.text(title, margin, margin + 18);

  if (subtitle) {
    doc.setFontSize(10);
    doc.setTextColor(...colors.textLight);
    doc.text(subtitle, margin, margin + 26);
  }

  // Date
  doc.setFontSize(9);
  doc.setTextColor(...colors.textLight);
  const dateText = `Generat la: ${formatDate(new Date())}`;
  doc.text(dateText, PDF_CONFIG.pageWidth - margin - doc.getTextWidth(dateText), margin + 8);

  // Line separator
  doc.setDrawColor(...colors.border);
  doc.setLineWidth(0.5);
  doc.line(margin, margin + 32, PDF_CONFIG.pageWidth - margin, margin + 32);

  return margin + 40;
};

/**
 * Add footer with page numbers
 */
const addFooter = (doc) => {
  const { pageWidth, pageHeight, margin, colors } = PDF_CONFIG;
  const pageCount = doc.internal.getNumberOfPages();

  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(9);
    doc.setTextColor(...colors.textLight);
    doc.text(
      `Pagina ${i} din ${pageCount}`,
      pageWidth / 2,
      pageHeight - margin / 2,
      { align: 'center' }
    );
  }
};

/**
 * Add summary cards section
 */
const addSummaryCards = (doc, startY, cards, fontFamily = 'Roboto') => {
  const { margin, colors, pageWidth } = PDF_CONFIG;
  const cardWidth = (pageWidth - margin * 2 - 15) / 4;
  const cardHeight = 25;

  cards.forEach((card, index) => {
    const x = margin + index * (cardWidth + 5);
    const y = startY;

    // Card background
    doc.setFillColor(248, 250, 252);
    doc.roundedRect(x, y, cardWidth, cardHeight, 2, 2, 'F');

    // Card title
    doc.setFontSize(8);
    doc.setTextColor(...colors.textLight);
    doc.setFont(fontFamily, 'normal');
    doc.text(card.title, x + 4, y + 7);

    // Card value
    doc.setFontSize(12);
    doc.setTextColor(...(card.color || colors.text));
    doc.setFont(fontFamily, 'bold');
    doc.text(card.value, x + 4, y + 17);

    // Card subtitle
    if (card.subtitle) {
      doc.setFontSize(7);
      doc.setTextColor(...colors.textLight);
      doc.setFont(fontFamily, 'normal');
      doc.text(card.subtitle, x + 4, y + 22);
    }
  });

  return startY + cardHeight + 10;
};

/**
 * Export Collection Report to PDF
 */
export const exportCollectionReportPDF = async (data, year, month) => {
  const { doc, fontFamily } = await initPdfDoc();
  const { margin, colors } = PDF_CONFIG;

  const monthNames = ['Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
    'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'];

  const periodText = month
    ? `${monthNames[month - 1]} ${year}`
    : `Anul ${year}`;

  let currentY = addHeader(doc, 'Situație Încasări', periodText, fontFamily);

  // Summary cards
  const summaryCards = [
    {
      title: 'Total Emis',
      value: formatCurrency(parseFloat(data.summary?.issued_total || 0)),
      subtitle: `${data.summary?.issued_count || 0} facturi`,
    },
    {
      title: 'Total Încasat',
      value: formatCurrency(parseFloat(data.summary?.collected_total || 0)),
      subtitle: `${data.summary?.collected_count || 0} plăți`,
      color: colors.success,
    },
    {
      title: 'Rest de Încasat',
      value: formatCurrency(parseFloat(data.summary?.outstanding || 0)),
      subtitle: `${data.summary?.outstanding_count || 0} facturi restante`,
      color: colors.warning,
    },
    {
      title: 'Rată Încasare',
      value: `${parseFloat(data.summary?.collection_rate || 0).toFixed(1)}%`,
      color: parseFloat(data.summary?.collection_rate || 0) >= 80 ? colors.success : colors.warning,
    },
  ];

  currentY = addSummaryCards(doc, currentY, summaryCards, fontFamily);

  // Type breakdown table
  if (data.by_type && data.by_type.length > 0) {
    doc.setFontSize(12);
    doc.setTextColor(...colors.text);
    doc.setFont(fontFamily, 'bold');
    doc.text('Detaliere pe Tip Factură', margin, currentY + 5);
    currentY += 10;

    const typeLabels = {
      rent: 'Chirie',
      utility: 'Utilități',
      utilities: 'Utilități',
      generic: 'Generic',
      other: 'Altele',
    };

    autoTable(doc, {
      startY: currentY,
      head: [['Tip Factură', 'Emis', 'Încasat', 'Rată Încasare']],
      body: data.by_type.map(row => [
        typeLabels[row.type] || row.type,
        formatCurrency(parseFloat(row.issued)),
        formatCurrency(parseFloat(row.collected)),
        `${parseFloat(row.collection_rate).toFixed(1)}%`,
      ]),
      styles: {
        fontSize: 9,
        cellPadding: 4,
        font: fontFamily,
      },
      headStyles: {
        fillColor: colors.primary,
        textColor: [255, 255, 255],
        fontStyle: 'bold',
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252],
      },
      margin: { left: margin, right: margin },
    });

    currentY = doc.lastAutoTable.finalY + 10;
  }

  // Monthly breakdown table (if full year)
  if (!month && data.monthly && data.monthly.length > 0) {
    doc.setFontSize(12);
    doc.setTextColor(...colors.text);
    doc.setFont(fontFamily, 'bold');
    doc.text('Evoluție Lunară', margin, currentY + 5);
    currentY += 10;

    autoTable(doc, {
      startY: currentY,
      head: [['Lună', 'Emis', 'Încasat', 'Diferență']],
      body: data.monthly.map(row => {
        const diff = parseFloat(row.issued) - parseFloat(row.collected);
        return [
          monthNames[row.month - 1],
          formatCurrency(parseFloat(row.issued)),
          formatCurrency(parseFloat(row.collected)),
          formatCurrency(diff),
        ];
      }),
      styles: {
        fontSize: 9,
        cellPadding: 4,
        font: fontFamily,
      },
      headStyles: {
        fillColor: colors.primary,
        textColor: [255, 255, 255],
        fontStyle: 'bold',
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252],
      },
      margin: { left: margin, right: margin },
    });
  }

  addFooter(doc);

  // Download
  const filename = month
    ? `situatie-incasari-${year}-${String(month).padStart(2, '0')}.pdf`
    : `situatie-incasari-${year}.pdf`;
  doc.save(filename);
};

/**
 * Export Tenant Statement to PDF
 */
export const exportTenantStatementPDF = async (data) => {
  const { doc, fontFamily } = await initPdfDoc();
  const { margin, colors } = PDF_CONFIG;

  const periodText = data.period?.start_date && data.period?.end_date
    ? `${formatDate(data.period.start_date)} - ${formatDate(data.period.end_date)}`
    : 'Toate tranzacțiile';

  let currentY = addHeader(doc, 'Extras de Cont', data.tenant?.name || '', fontFamily);

  // Tenant info
  doc.setFillColor(248, 250, 252);
  doc.roundedRect(margin, currentY, PDF_CONFIG.pageWidth - margin * 2, 25, 2, 2, 'F');

  doc.setFontSize(10);
  doc.setTextColor(...colors.text);
  doc.setFont(fontFamily, 'bold');
  doc.text(`Chiriaș: ${data.tenant?.name || '-'}`, margin + 5, currentY + 8);

  doc.setFont(fontFamily, 'normal');
  doc.setTextColor(...colors.textLight);
  if (data.tenant?.email) {
    doc.text(`Email: ${data.tenant.email}`, margin + 5, currentY + 15);
  }

  doc.setFont(fontFamily, 'bold');
  doc.setTextColor(...colors.text);
  doc.text(`Total Facturat: ${formatCurrency(parseFloat(data.summary?.total_invoiced || 0))}`, margin + 100, currentY + 8);

  const balanceColor = parseFloat(data.summary?.current_balance || 0) > 0 ? colors.error : colors.success;
  doc.setTextColor(...balanceColor);
  doc.text(`Sold Curent: ${formatCurrency(parseFloat(data.summary?.current_balance || 0))}`, margin + 100, currentY + 15);

  currentY += 35;

  // Transactions table
  if (data.transactions && data.transactions.length > 0) {
    doc.setFontSize(12);
    doc.setTextColor(...colors.text);
    doc.setFont(fontFamily, 'bold');
    doc.text('Tranzacții', margin, currentY);
    currentY += 7;

    autoTable(doc, {
      startY: currentY,
      head: [['Data', 'Descriere', 'Debit', 'Credit', 'Sold']],
      body: data.transactions.map(row => [
        formatDate(row.date),
        row.description,
        row.debit ? formatCurrency(parseFloat(row.debit)) : '-',
        row.credit ? formatCurrency(parseFloat(row.credit)) : '-',
        formatCurrency(parseFloat(row.balance)),
      ]),
      styles: {
        fontSize: 8,
        cellPadding: 3,
        font: fontFamily,
      },
      headStyles: {
        fillColor: colors.primary,
        textColor: [255, 255, 255],
        fontStyle: 'bold',
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252],
      },
      columnStyles: {
        0: { cellWidth: 25 },
        1: { cellWidth: 'auto' },
        2: { cellWidth: 30, halign: 'right' },
        3: { cellWidth: 30, halign: 'right' },
        4: { cellWidth: 30, halign: 'right' },
      },
      margin: { left: margin, right: margin },
      didParseCell: (hookData) => {
        // Color debit/credit cells
        if (hookData.section === 'body') {
          if (hookData.column.index === 2 && hookData.cell.raw !== '-') {
            hookData.cell.styles.textColor = colors.error;
          }
          if (hookData.column.index === 3 && hookData.cell.raw !== '-') {
            hookData.cell.styles.textColor = colors.success;
          }
        }
      },
    });

    // Final balance row
    const lastY = doc.lastAutoTable.finalY;
    doc.setFillColor(240, 240, 240);
    doc.rect(margin, lastY, PDF_CONFIG.pageWidth - margin * 2, 10, 'F');
    doc.setFontSize(10);
    doc.setFont(fontFamily, 'bold');
    doc.setTextColor(...colors.text);
    doc.text('Sold Final:', margin + 5, lastY + 7);

    const finalBalance = data.transactions.length > 0
      ? parseFloat(data.transactions[data.transactions.length - 1].balance)
      : 0;
    doc.setTextColor(...(finalBalance > 0 ? colors.error : colors.success));
    doc.text(formatCurrency(finalBalance), PDF_CONFIG.pageWidth - margin - 5, lastY + 7, { align: 'right' });
  }

  addFooter(doc);

  // Download
  const tenantSlug = (data.tenant?.name || 'chiriaș').toLowerCase().replace(/\s+/g, '-');
  doc.save(`extras-cont-${tenantSlug}.pdf`);
};

/**
 * Export Calendar Events to PDF
 */
export const exportCalendarPDF = async (events, monthDate) => {
  const { doc, fontFamily } = await initPdfDoc();
  const { margin, colors } = PDF_CONFIG;

  const monthNames = ['Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
    'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'];

  const monthText = `${monthNames[monthDate.month()]} ${monthDate.year()}`;

  let currentY = addHeader(doc, 'Calendar Scadențe', monthText, fontFamily);

  if (events && events.length > 0) {
    autoTable(doc, {
      startY: currentY,
      head: [['Data', 'Tip', 'Descriere', 'Sumă', 'Status']],
      body: events.map(row => [
        formatDate(row.date),
        row.type === 'income' ? 'Încasare' : 'Plată',
        row.title,
        formatCurrency(parseFloat(row.amount)),
        row.is_paid ? 'Plătit' : 'În așteptare',
      ]),
      styles: {
        fontSize: 9,
        cellPadding: 4,
        font: fontFamily,
      },
      headStyles: {
        fillColor: colors.primary,
        textColor: [255, 255, 255],
        fontStyle: 'bold',
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252],
      },
      columnStyles: {
        0: { cellWidth: 25 },
        1: { cellWidth: 25 },
        2: { cellWidth: 'auto' },
        3: { cellWidth: 35, halign: 'right' },
        4: { cellWidth: 30 },
      },
      margin: { left: margin, right: margin },
      didParseCell: (hookData) => {
        if (hookData.section === 'body') {
          // Type column coloring
          if (hookData.column.index === 1) {
            hookData.cell.styles.textColor = hookData.cell.raw === 'Încasare'
              ? colors.primary
              : [234, 179, 8];
          }
          // Status column coloring
          if (hookData.column.index === 4) {
            hookData.cell.styles.textColor = hookData.cell.raw === 'Plătit'
              ? colors.success
              : colors.warning;
          }
        }
      },
    });
  } else {
    doc.setFontSize(11);
    doc.setTextColor(...colors.textLight);
    doc.setFont(fontFamily, 'normal');
    doc.text('Nu există scadențe pentru această lună.', margin, currentY + 10);
  }

  addFooter(doc);

  doc.save(`calendar-scadente-${monthDate.format('YYYY-MM')}.pdf`);
};

export default {
  exportCollectionReportPDF,
  exportTenantStatementPDF,
  exportCalendarPDF,
};

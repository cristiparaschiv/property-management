import React from 'react';
import '../../styles/components/animations.css';

/**
 * TableSkeleton - Loading skeleton for tables
 * @param {number} rows - Number of skeleton rows
 * @param {number} columns - Number of columns
 * @param {boolean} showHeader - Whether to show header skeleton
 * @param {Array} columnWidths - Optional array of column width percentages
 */
const TableSkeleton = ({
  rows = 5,
  columns = 4,
  showHeader = true,
  columnWidths,
}) => {
  const getColumnWidth = (index) => {
    if (columnWidths && columnWidths[index]) {
      return columnWidths[index];
    }
    // Default widths: first column wider, last column narrow (for actions)
    if (index === 0) return '25%';
    if (index === columns - 1) return '10%';
    return `${65 / (columns - 2)}%`;
  };

  return (
    <div className="pm-table-skeleton" style={{ width: '100%' }}>
      {/* Header */}
      {showHeader && (
        <div
          style={{
            display: 'flex',
            gap: '16px',
            padding: '12px 16px',
            background: 'var(--pm-color-bg-tertiary)',
            borderBottom: '2px solid var(--pm-color-border-default)',
            borderRadius: 'var(--pm-radius-lg) var(--pm-radius-lg) 0 0',
          }}
        >
          {Array.from({ length: columns }).map((_, i) => (
            <div
              key={`header-${i}`}
              className="pm-skeleton"
              style={{
                height: '14px',
                width: getColumnWidth(i),
                borderRadius: 'var(--pm-radius-sm)',
              }}
            />
          ))}
        </div>
      )}

      {/* Rows */}
      {Array.from({ length: rows }).map((_, rowIndex) => (
        <div
          key={`row-${rowIndex}`}
          style={{
            display: 'flex',
            gap: '16px',
            padding: '16px',
            borderBottom: '1px solid var(--pm-color-border-subtle)',
            background: rowIndex % 2 === 0 ? 'transparent' : 'var(--pm-color-bg-tertiary)',
          }}
        >
          {Array.from({ length: columns }).map((_, colIndex) => (
            <div
              key={`cell-${rowIndex}-${colIndex}`}
              className="pm-skeleton"
              style={{
                height: '16px',
                width: getColumnWidth(colIndex),
                borderRadius: 'var(--pm-radius-sm)',
                animationDelay: `${(rowIndex * columns + colIndex) * 50}ms`,
              }}
            />
          ))}
        </div>
      ))}
    </div>
  );
};

export default TableSkeleton;

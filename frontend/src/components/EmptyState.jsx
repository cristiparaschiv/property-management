import React from 'react';
import { Button } from 'antd';
import {
  PlusOutlined,
  InboxOutlined,
  FileSearchOutlined,
  DatabaseOutlined,
} from '@ant-design/icons';
import '../styles/components/animations.css';

// Icon variants for different contexts
const iconVariants = {
  default: InboxOutlined,
  search: FileSearchOutlined,
  data: DatabaseOutlined,
};

/**
 * EmptyState - Enhanced empty state component
 * @param {string} title - Optional title text
 * @param {string} description - Description text
 * @param {string} actionText - Text for action button
 * @param {function} onAction - Click handler for action button
 * @param {React.ReactNode} icon - Custom icon for action button
 * @param {string} variant - Icon variant: default, search, data
 * @param {boolean} compact - Use compact layout
 */
const EmptyState = ({
  title,
  description = 'Nu există date',
  actionText,
  onAction,
  icon,
  variant = 'default',
  compact = false,
}) => {
  const IconComponent = iconVariants[variant] || iconVariants.default;

  return (
    <div
      className="pm-fade-in-up"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: compact ? 'var(--pm-space-xl)' : 'var(--pm-space-3xl)',
        textAlign: 'center',
      }}
    >
      {/* Icon Container */}
      <div
        style={{
          width: compact ? 64 : 80,
          height: compact ? 64 : 80,
          borderRadius: 'var(--pm-radius-full)',
          background: 'var(--pm-color-bg-tertiary)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 'var(--pm-space-lg)',
          position: 'relative',
        }}
      >
        {/* Decorative ring */}
        <div
          style={{
            position: 'absolute',
            inset: -8,
            borderRadius: 'var(--pm-radius-full)',
            border: '2px dashed var(--pm-color-border-default)',
            opacity: 0.5,
          }}
        />
        <IconComponent
          style={{
            fontSize: compact ? 28 : 36,
            color: 'var(--pm-color-text-tertiary)',
          }}
        />
      </div>

      {/* Title */}
      {title && (
        <h3
          style={{
            fontSize: 'var(--pm-font-size-lg)',
            fontWeight: 'var(--pm-font-weight-semibold)',
            color: 'var(--pm-color-text-primary)',
            margin: '0 0 var(--pm-space-xs) 0',
          }}
        >
          {title}
        </h3>
      )}

      {/* Description */}
      <p
        style={{
          fontSize: 'var(--pm-font-size-sm)',
          color: 'var(--pm-color-text-tertiary)',
          margin: 0,
          maxWidth: 280,
          lineHeight: 1.6,
        }}
      >
        {description}
      </p>

      {/* Action Button */}
      {actionText && onAction && (
        <Button
          type="primary"
          icon={icon || <PlusOutlined />}
          onClick={onAction}
          style={{
            marginTop: 'var(--pm-space-lg)',
            borderRadius: 'var(--pm-radius-lg)',
            height: 40,
          }}
          className="pm-btn-hover"
        >
          {actionText}
        </Button>
      )}
    </div>
  );
};

export default EmptyState;

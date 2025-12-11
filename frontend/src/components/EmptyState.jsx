import React from 'react';
import { Empty, Button } from 'antd';
import { PlusOutlined } from '@ant-design/icons';

const EmptyState = ({
  description = 'Nu există date',
  actionText,
  onAction,
  icon,
  image,
}) => {
  return (
    <Empty
      image={image || Empty.PRESENTED_IMAGE_SIMPLE}
      description={description}
      style={{ padding: '48px 0' }}
    >
      {actionText && onAction && (
        <Button
          type="primary"
          icon={icon || <PlusOutlined />}
          onClick={onAction}
        >
          {actionText}
        </Button>
      )}
    </Empty>
  );
};

export default EmptyState;

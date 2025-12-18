import React from 'react';
import { Timeline, Tag, Empty, Spin, Typography } from 'antd';
import {
  PlusCircleOutlined,
  EditOutlined,
  DeleteOutlined,
  DollarOutlined,
  LoginOutlined,
  InfoCircleOutlined,
  UserOutlined,
  FileTextOutlined,
  ShopOutlined,
  TeamOutlined,
  ThunderboltOutlined,
  CalculatorOutlined,
} from '@ant-design/icons';
import { useQuery } from '@tanstack/react-query';
import { activityLogsService } from '../services/activityLogsService';
import { formatDate } from '../utils/formatters';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/ro';

dayjs.extend(relativeTime);
dayjs.locale('ro');

const { Text } = Typography;

const ActivityLogWidget = ({ limit = 10 }) => {
  const { data, isLoading, error } = useQuery({
    queryKey: ['activity-logs-recent', limit],
    queryFn: () => activityLogsService.getRecent(limit),
    refetchInterval: 30000, // Refresh every 30 seconds
  });

  const getActionIcon = (actionType) => {
    const icons = {
      create: <PlusCircleOutlined style={{ color: 'var(--pm-color-success)' }} />,
      update: <EditOutlined style={{ color: 'var(--pm-color-primary)' }} />,
      delete: <DeleteOutlined style={{ color: 'var(--pm-color-error)' }} />,
      payment: <DollarOutlined style={{ color: 'var(--pm-color-warning)' }} />,
      login: <LoginOutlined style={{ color: 'var(--pm-color-info)' }} />,
      other: <InfoCircleOutlined style={{ color: 'var(--pm-color-text-secondary)' }} />,
    };
    return icons[actionType] || icons.other;
  };

  const getEntityIcon = (entityType) => {
    const icons = {
      tenant: <TeamOutlined />,
      invoice: <FileTextOutlined />,
      received_invoice: <FileTextOutlined />,
      utility_provider: <ShopOutlined />,
      meter: <ThunderboltOutlined />,
      meter_reading: <ThunderboltOutlined />,
      calculation: <CalculatorOutlined />,
      user: <UserOutlined />,
    };
    return icons[entityType] || <InfoCircleOutlined />;
  };

  const getActionColor = (actionType) => {
    const colors = {
      create: 'green',
      update: 'blue',
      delete: 'red',
      payment: 'gold',
      login: 'cyan',
      other: 'default',
    };
    return colors[actionType] || 'default';
  };

  const getActionLabel = (actionType) => {
    const labels = {
      create: 'Creare',
      update: 'Modificare',
      delete: 'Ștergere',
      payment: 'Plată',
      login: 'Autentificare',
      other: 'Altele',
    };
    return labels[actionType] || actionType;
  };

  const formatTimeAgo = (date) => {
    return dayjs(date).fromNow();
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '40px' }}>
        <Spin />
      </div>
    );
  }

  if (error) {
    return (
      <Empty
        description="Nu s-au putut încărca activitățile"
        image={Empty.PRESENTED_IMAGE_SIMPLE}
      />
    );
  }

  const logsRaw = data?.data;
  const logs = Array.isArray(logsRaw) ? logsRaw : [];

  if (logs.length === 0) {
    return (
      <Empty
        description="Nu există activități recente"
        image={Empty.PRESENTED_IMAGE_SIMPLE}
      />
    );
  }

  return (
    <Timeline
      items={logs.map((log) => ({
        dot: getActionIcon(log.action_type),
        children: (
          <div className="pm-activity-item">
            <div className="pm-activity-item__header">
              <Tag color={getActionColor(log.action_type)} style={{ marginRight: 8 }}>
                {getActionLabel(log.action_type)}
              </Tag>
              <Text type="secondary" style={{ fontSize: 12 }}>
                {formatTimeAgo(log.created_at)}
              </Text>
            </div>
            <div className="pm-activity-item__description">
              {log.description}
            </div>
            <div className="pm-activity-item__footer">
              <Text type="secondary" style={{ fontSize: 11 }}>
                {getEntityIcon(log.entity_type)} {log.entity_name || log.entity_type}
                {log.user_name && (
                  <span style={{ marginLeft: 8 }}>
                    <UserOutlined style={{ marginRight: 4 }} />
                    {log.user_name}
                  </span>
                )}
              </Text>
            </div>
          </div>
        ),
      }))}
    />
  );
};

export default ActivityLogWidget;

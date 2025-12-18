import React, { useState, useEffect } from 'react';
import {
  Badge,
  Button,
  Dropdown,
  List,
  Empty,
  Spin,
  Typography,
  Tag,
  Tooltip,
  message,
} from 'antd';
import {
  BellOutlined,
  WarningOutlined,
  InfoCircleOutlined,
  CloseCircleOutlined,
  CheckCircleOutlined,
  CheckOutlined,
  CloseOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { notificationsService } from '../services/notificationsService';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/ro';

dayjs.extend(relativeTime);
dayjs.locale('ro');

const { Text } = Typography;

const NotificationBell = () => {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Fetch notification count
  const { data: countData } = useQuery({
    queryKey: ['notifications-count'],
    queryFn: () => notificationsService.getCount(),
    refetchInterval: 60000, // Check every minute
  });

  // Fetch notifications when dropdown opens
  const { data: notificationsData, isLoading, refetch } = useQuery({
    queryKey: ['notifications'],
    queryFn: () => notificationsService.getAll({ include_read: 0 }),
    enabled: open,
  });

  // Check for new notifications periodically
  const { mutate: checkNotifications } = useMutation({
    mutationFn: () => notificationsService.check(),
    onSuccess: (data) => {
      if (data?.data?.created > 0) {
        queryClient.invalidateQueries(['notifications-count']);
        queryClient.invalidateQueries(['notifications']);
      }
    },
  });

  // Mark as read mutation
  const markAsReadMutation = useMutation({
    mutationFn: (id) => notificationsService.markAsRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries(['notifications']);
      queryClient.invalidateQueries(['notifications-count']);
    },
  });

  // Mark all as read mutation
  const markAllAsReadMutation = useMutation({
    mutationFn: () => notificationsService.markAllAsRead(),
    onSuccess: () => {
      message.success('Toate notificările au fost marcate ca citite');
      queryClient.invalidateQueries(['notifications']);
      queryClient.invalidateQueries(['notifications-count']);
    },
  });

  // Dismiss mutation
  const dismissMutation = useMutation({
    mutationFn: (id) => notificationsService.dismiss(id),
    onSuccess: () => {
      queryClient.invalidateQueries(['notifications']);
      queryClient.invalidateQueries(['notifications-count']);
    },
  });

  // Check for new notifications every 5 minutes
  useEffect(() => {
    checkNotifications();
    const interval = setInterval(() => {
      checkNotifications();
    }, 300000); // 5 minutes

    return () => clearInterval(interval);
  }, []);

  const getTypeIcon = (type) => {
    const icons = {
      warning: <WarningOutlined style={{ color: 'var(--pm-color-warning)' }} />,
      error: <CloseCircleOutlined style={{ color: 'var(--pm-color-error)' }} />,
      success: <CheckCircleOutlined style={{ color: 'var(--pm-color-success)' }} />,
      info: <InfoCircleOutlined style={{ color: 'var(--pm-color-info)' }} />,
    };
    return icons[type] || icons.info;
  };

  const getTypeColor = (type) => {
    const colors = {
      warning: 'gold',
      error: 'red',
      success: 'green',
      info: 'blue',
    };
    return colors[type] || 'blue';
  };

  const handleNotificationClick = (notification) => {
    if (!notification.is_read) {
      markAsReadMutation.mutate(notification.id);
    }
    if (notification.link) {
      navigate(notification.link);
      setOpen(false);
    }
  };

  const count = countData?.data?.count || 0;
  const notificationsRaw = notificationsData?.data;
  const notifications = Array.isArray(notificationsRaw) ? notificationsRaw : [];

  const dropdownContent = (
    <div className="pm-notifications-dropdown">
      <div className="pm-notifications-dropdown__header">
        <Text strong>Notificări</Text>
        {count > 0 && (
          <Button
            type="link"
            size="small"
            onClick={() => markAllAsReadMutation.mutate()}
            loading={markAllAsReadMutation.isPending}
          >
            Marchează toate ca citite
          </Button>
        )}
      </div>
      <div className="pm-notifications-dropdown__content">
        {isLoading ? (
          <div style={{ textAlign: 'center', padding: '20px' }}>
            <Spin />
          </div>
        ) : notifications.length === 0 ? (
          <Empty
            description="Nu aveți notificări"
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            style={{ padding: '20px' }}
          />
        ) : (
          <List
            dataSource={notifications}
            renderItem={(item) => (
              <List.Item
                className={`pm-notification-item ${!item.is_read ? 'pm-notification-item--unread' : ''}`}
                onClick={() => handleNotificationClick(item)}
                actions={[
                  <Tooltip title="Respinge" key="dismiss">
                    <Button
                      type="text"
                      size="small"
                      icon={<CloseOutlined />}
                      onClick={(e) => {
                        e.stopPropagation();
                        dismissMutation.mutate(item.id);
                      }}
                    />
                  </Tooltip>,
                ]}
              >
                <List.Item.Meta
                  avatar={getTypeIcon(item.type)}
                  title={
                    <div>
                      <Tag color={getTypeColor(item.type)} style={{ marginRight: 8 }}>
                        {item.title}
                      </Tag>
                    </div>
                  }
                  description={
                    <div>
                      <div className="pm-notification-item__message">{item.message}</div>
                      <Text type="secondary" style={{ fontSize: 11 }}>
                        {dayjs(item.created_at).fromNow()}
                      </Text>
                    </div>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </div>
    </div>
  );

  return (
    <Dropdown
      dropdownRender={() => dropdownContent}
      trigger={['click']}
      open={open}
      onOpenChange={(visible) => {
        setOpen(visible);
        if (visible) {
          refetch();
        }
      }}
      placement="bottomRight"
    >
      <Tooltip title="Notificări">
        <Button
          type="text"
          className="pm-header__action"
          icon={
            <Badge count={count} size="small" offset={[-2, 2]}>
              <BellOutlined style={{ fontSize: 18 }} />
            </Badge>
          }
        />
      </Tooltip>
    </Dropdown>
  );
};

export default NotificationBell;

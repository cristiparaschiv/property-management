import React, { useEffect, useState } from 'react';
import {
  Card,
  Button,
  Table,
  Tag,
  Space,
  Modal,
  message,
  Alert,
  Typography,
  Tooltip,
  Input,
  Descriptions,
  Spin,
  Empty,
  Popconfirm,
  Progress,
} from 'antd';
import {
  GoogleOutlined,
  CloudUploadOutlined,
  CloudDownloadOutlined,
  DeleteOutlined,
  ReloadOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  LoadingOutlined,
  DisconnectOutlined,
  LinkOutlined,
  WarningOutlined,
  CloudOutlined,
} from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { googleDriveService } from '../services/googleDriveService';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/ro';

dayjs.extend(relativeTime);
dayjs.locale('ro');

const { Title, Text, Paragraph } = Typography;

const Backups = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [restoreModalVisible, setRestoreModalVisible] = useState(false);
  const [selectedBackup, setSelectedBackup] = useState(null);
  const [confirmText, setConfirmText] = useState('');
  const queryClient = useQueryClient();

  // Check for OAuth callback params
  useEffect(() => {
    const googleStatus = searchParams.get('google');
    const errorMessage = searchParams.get('message');

    if (googleStatus === 'connected') {
      message.success('Google Drive conectat cu succes!');
      queryClient.invalidateQueries(['google-drive-status']);
      setSearchParams({});
    } else if (googleStatus === 'error') {
      message.error(`Eroare la conectare: ${errorMessage || 'Unknown error'}`);
      setSearchParams({});
    }
  }, [searchParams, setSearchParams, queryClient]);

  // Fetch Google Drive status
  const { data: statusData, isLoading: statusLoading } = useQuery({
    queryKey: ['google-drive-status'],
    queryFn: () => googleDriveService.getStatus(),
  });

  // Fetch backup history
  const { data: backupsData, isLoading: backupsLoading, refetch: refetchBackups } = useQuery({
    queryKey: ['backups'],
    queryFn: () => googleDriveService.getBackups(),
  });

  // Get auth URL mutation
  const getAuthUrlMutation = useMutation({
    mutationFn: () => googleDriveService.getAuthUrl(),
    onSuccess: (response) => {
      const url = response?.data?.data?.url;
      if (url) {
        window.location.href = url;
      } else {
        message.error('Nu s-a putut obține URL-ul de autorizare');
      }
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la conectare');
    },
  });

  // Disconnect mutation
  const disconnectMutation = useMutation({
    mutationFn: () => googleDriveService.disconnect(),
    onSuccess: () => {
      message.success('Deconectat de la Google Drive');
      queryClient.invalidateQueries(['google-drive-status']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la deconectare');
    },
  });

  // Create backup mutation
  const createBackupMutation = useMutation({
    mutationFn: () => googleDriveService.createBackup(),
    onSuccess: () => {
      message.success('Backup creat și încărcat în Google Drive!');
      queryClient.invalidateQueries(['backups']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la crearea backup-ului');
    },
  });

  // Restore mutation
  const restoreMutation = useMutation({
    mutationFn: (id) => googleDriveService.restoreBackup(id),
    onSuccess: () => {
      message.success('Baza de date a fost restaurată cu succes!');
      setRestoreModalVisible(false);
      setSelectedBackup(null);
      setConfirmText('');
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la restaurare');
    },
  });

  // Delete backup mutation
  const deleteBackupMutation = useMutation({
    mutationFn: ({ id, deleteFromDrive }) => googleDriveService.deleteBackup(id, deleteFromDrive),
    onSuccess: () => {
      message.success('Backup șters');
      queryClient.invalidateQueries(['backups']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const status = statusData?.data?.data;
  const backups = backupsData?.data?.data || [];
  const isConnected = status?.connected;

  const formatFileSize = (bytes) => {
    if (!bytes) return '-';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(2)} ${sizes[i]}`;
  };

  const getStatusTag = (backupStatus) => {
    const statusConfig = {
      pending: { color: 'default', icon: <LoadingOutlined />, text: 'În așteptare' },
      creating: { color: 'processing', icon: <LoadingOutlined spin />, text: 'Se creează' },
      uploading: { color: 'processing', icon: <CloudUploadOutlined />, text: 'Se încarcă' },
      completed: { color: 'success', icon: <CheckCircleOutlined />, text: 'Complet' },
      failed: { color: 'error', icon: <CloseCircleOutlined />, text: 'Eșuat' },
    };
    const config = statusConfig[backupStatus] || statusConfig.pending;
    return (
      <Tag color={config.color} icon={config.icon}>
        {config.text}
      </Tag>
    );
  };

  const columns = [
    {
      title: 'Nume fișier',
      dataIndex: 'file_name',
      key: 'file_name',
      render: (text) => <Text strong>{text}</Text>,
    },
    {
      title: 'Dimensiune',
      dataIndex: 'file_size',
      key: 'file_size',
      render: (size) => formatFileSize(size),
      width: 120,
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status) => getStatusTag(status),
      width: 130,
    },
    {
      title: 'Creat de',
      dataIndex: 'created_by',
      key: 'created_by',
      render: (name) => name || 'System',
      width: 150,
    },
    {
      title: 'Data',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (date) => (
        <Tooltip title={dayjs(date).format('DD.MM.YYYY HH:mm:ss')}>
          {dayjs(date).fromNow()}
        </Tooltip>
      ),
      width: 150,
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      width: 150,
      render: (_, record) => (
        <Space>
          {record.status === 'completed' && record.drive_file_id && (
            <Tooltip title="Restaurare">
              <Button
                type="text"
                icon={<CloudDownloadOutlined />}
                onClick={() => {
                  setSelectedBackup(record);
                  setRestoreModalVisible(true);
                }}
              />
            </Tooltip>
          )}
          <Popconfirm
            title="Șterge backup"
            description="Sigur doriți să ștergeți acest backup?"
            onConfirm={() => deleteBackupMutation.mutate({ id: record.id, deleteFromDrive: true })}
            okText="Da"
            cancelText="Nu"
          >
            <Tooltip title="Șterge">
              <Button type="text" danger icon={<DeleteOutlined />} />
            </Tooltip>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  const handleRestore = () => {
    if (confirmText !== 'RESTAURARE') {
      message.error('Trebuie să introduceți "RESTAURARE" pentru a confirma');
      return;
    }
    restoreMutation.mutate(selectedBackup.id);
  };

  if (statusLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '50px' }}>
        <Spin size="large" />
      </div>
    );
  }

  return (
    <div className="pm-backups-page">
      <div className="pm-page-header">
        <div className="pm-page-header__title-row">
          <Title level={2} className="pm-page-header__title">
            Backup & Restaurare
          </Title>
        </div>
      </div>

      {/* Google Drive Connection Card */}
      <Card
        title={
          <Space>
            <GoogleOutlined style={{ color: '#4285f4' }} />
            <span>Google Drive</span>
          </Space>
        }
        style={{ marginBottom: 24 }}
      >
        {isConnected ? (
          <div>
            <Descriptions column={1} size="small">
              <Descriptions.Item label="Status">
                <Tag color="success" icon={<CheckCircleOutlined />}>
                  Conectat
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="Cont">
                {status?.email}
              </Descriptions.Item>
              <Descriptions.Item label="Folder backup">
                <Space>
                  <CloudOutlined />
                  {status?.folder_name || 'Domistra Backups'}
                </Space>
              </Descriptions.Item>
              <Descriptions.Item label="Conectat la">
                {status?.connected_at ? dayjs(status.connected_at).format('DD.MM.YYYY HH:mm') : '-'}
              </Descriptions.Item>
            </Descriptions>
            <div style={{ marginTop: 16 }}>
              <Popconfirm
                title="Deconectare Google Drive"
                description="Sigur doriți să vă deconectați? Backup-urile existente vor rămâne în Google Drive."
                onConfirm={() => disconnectMutation.mutate()}
                okText="Da, deconectează"
                cancelText="Anulează"
              >
                <Button
                  icon={<DisconnectOutlined />}
                  loading={disconnectMutation.isPending}
                >
                  Deconectare
                </Button>
              </Popconfirm>
            </div>
          </div>
        ) : (
          <div>
            <Alert
              message="Google Drive nu este conectat"
              description="Conectați-vă la Google Drive pentru a activa backup-urile automate în cloud. Backup-urile vor fi stocate în folderul 'Domistra Backups' din contul dvs. Google Drive."
              type="info"
              showIcon
              style={{ marginBottom: 16 }}
            />
            <Button
              type="primary"
              icon={<LinkOutlined />}
              onClick={() => getAuthUrlMutation.mutate()}
              loading={getAuthUrlMutation.isPending}
            >
              Conectare la Google Drive
            </Button>
          </div>
        )}
      </Card>

      {/* Backup Actions Card */}
      {isConnected && (
        <Card
          title="Creare Backup"
          style={{ marginBottom: 24 }}
        >
          <Paragraph type="secondary">
            Creați un backup complet al bazei de date. Backup-ul va fi comprimat și încărcat automat în Google Drive.
          </Paragraph>
          <Button
            type="primary"
            icon={<CloudUploadOutlined />}
            onClick={() => createBackupMutation.mutate()}
            loading={createBackupMutation.isPending}
            size="large"
          >
            {createBackupMutation.isPending ? 'Se creează backup...' : 'Creare Backup Acum'}
          </Button>
        </Card>
      )}

      {/* Backup History Card */}
      <Card
        title="Istoric Backup-uri"
        extra={
          <Button
            icon={<ReloadOutlined />}
            onClick={() => refetchBackups()}
            loading={backupsLoading}
          >
            Reîmprospătare
          </Button>
        }
      >
        {backupsLoading ? (
          <div style={{ textAlign: 'center', padding: 40 }}>
            <Spin />
          </div>
        ) : backups.length === 0 ? (
          <Empty
            description="Nu există backup-uri"
            image={Empty.PRESENTED_IMAGE_SIMPLE}
          />
        ) : (
          <Table
            dataSource={backups}
            columns={columns}
            rowKey="id"
            pagination={{ pageSize: 10 }}
            size="small"
          />
        )}
      </Card>

      {/* Restore Confirmation Modal */}
      <Modal
        title={
          <Space>
            <WarningOutlined style={{ color: '#faad14' }} />
            <span>Confirmare Restaurare</span>
          </Space>
        }
        open={restoreModalVisible}
        onCancel={() => {
          setRestoreModalVisible(false);
          setSelectedBackup(null);
          setConfirmText('');
        }}
        footer={[
          <Button
            key="cancel"
            onClick={() => {
              setRestoreModalVisible(false);
              setSelectedBackup(null);
              setConfirmText('');
            }}
          >
            Anulează
          </Button>,
          <Button
            key="restore"
            type="primary"
            danger
            icon={<CloudDownloadOutlined />}
            onClick={handleRestore}
            loading={restoreMutation.isPending}
            disabled={confirmText !== 'RESTAURARE'}
          >
            Restaurare
          </Button>,
        ]}
      >
        <Alert
          message="Atenție! Această acțiune este ireversibilă!"
          description={
            <div>
              <p>Restaurarea va:</p>
              <ul>
                <li>Suprascrie complet baza de date curentă</li>
                <li>Șterge toate datele adăugate după data backup-ului</li>
                <li>Restaura datele la starea din: <strong>{selectedBackup?.file_name}</strong></li>
              </ul>
            </div>
          }
          type="warning"
          showIcon
          style={{ marginBottom: 16 }}
        />
        <Paragraph>
          Pentru a confirma restaurarea, introduceți <Text strong>RESTAURARE</Text> în câmpul de mai jos:
        </Paragraph>
        <Input
          placeholder="Introduceți RESTAURARE pentru confirmare"
          value={confirmText}
          onChange={(e) => setConfirmText(e.target.value.toUpperCase())}
          status={confirmText && confirmText !== 'RESTAURARE' ? 'error' : ''}
        />
      </Modal>
    </div>
  );
};

export default Backups;

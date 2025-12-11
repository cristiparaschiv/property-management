import React, { useState } from 'react';
import {
  Table,
  Button,
  Space,
  Modal,
  Form,
  Input,
  Select,
  Switch,
  message,
  Popconfirm,
  Tag,
  Card,
  Dropdown,
} from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined, MoreOutlined } from '@ant-design/icons';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { metersService } from '../services/metersService';
import { tenantsService } from '../services/tenantsService';

const { Option } = Select;

const Meters = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingMeter, setEditingMeter] = useState(null);

  const { data: metersData, isLoading } = useQuery({
    queryKey: ['meters'],
    queryFn: () => metersService.getAll(),
  });

  const { data: tenantsData } = useQuery({
    queryKey: ['tenants'],
    queryFn: () => tenantsService.getAll(),
  });

  const createMutation = useMutation({
    mutationFn: (values) => metersService.create(values),
    onSuccess: () => {
      message.success('Contor adăugat cu succes!');
      queryClient.invalidateQueries(['meters']);
      setIsModalOpen(false);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la adăugare');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, values }) => metersService.update(id, values),
    onSuccess: () => {
      message.success('Contor actualizat cu succes!');
      queryClient.invalidateQueries(['meters']);
      setIsModalOpen(false);
      setEditingMeter(null);
      form.resetFields();
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizare');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => metersService.delete(id),
    onSuccess: () => {
      message.success('Contor șters cu succes!');
      queryClient.invalidateQueries(['meters']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la ștergere');
    },
  });

  const showCreateModal = () => {
    setEditingMeter(null);
    form.resetFields();
    setIsModalOpen(true);
  };

  const showEditModal = (meter) => {
    setEditingMeter(meter);
    form.setFieldsValue(meter);
    setIsModalOpen(true);
  };

  const handleOk = () => {
    form.validateFields().then((values) => {
      if (editingMeter) {
        updateMutation.mutate({ id: editingMeter.id, values });
      } else {
        createMutation.mutate(values);
      }
    });
  };

  const columns = [
    {
      title: 'Nume',
      dataIndex: 'name',
      key: 'name',
      sorter: (a, b) => a.name.localeCompare(b.name),
    },
    {
      title: 'Chiriaș',
      dataIndex: 'tenant_name',
      key: 'tenant_name',
      render: (name) => name || '-',
    },
    {
      title: 'Tip',
      dataIndex: 'is_general',
      key: 'is_general',
      render: (isGeneral) => (
        <Tag color={isGeneral ? 'blue' : 'green'}>
          {isGeneral ? 'General' : 'Individual'}
        </Tag>
      ),
    },
    {
      title: 'Locație',
      dataIndex: 'location',
      key: 'location',
    },
    {
      title: 'Acțiuni',
      key: 'actions',
      render: (_, record) => {
        const items = [
          {
            key: 'edit',
            icon: <EditOutlined />,
            label: 'Editează',
            onClick: () => showEditModal(record),
          },
          ...(!record.is_general ? [{
            key: 'delete',
            icon: <DeleteOutlined />,
            label: 'Șterge',
            danger: true,
            onClick: () => {
              Modal.confirm({
                title: 'Sigur doriți să ștergeți acest contor?',
                onOk: () => deleteMutation.mutate(record.id),
                okText: 'Da',
                cancelText: 'Nu',
              });
            },
          }] : []),
        ];

        return (
          <Dropdown
            menu={{ items }}
            trigger={['click']}
          >
            <Button icon={<MoreOutlined />} />
          </Dropdown>
        );
      },
    },
  ];

  const meters = metersData?.data || [];
  const tenants = tenantsData?.data?.tenants || [];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
        <h1>Contoare</h1>
        <Button
          type="primary"
          icon={<PlusOutlined />}
          onClick={showCreateModal}
        >
          Adaugă Contor
        </Button>
      </div>

      <Card>
        <Table
          columns={columns}
          dataSource={meters}
          rowKey="id"
          loading={isLoading}
          pagination={{ pageSize: 10 }}
        />
      </Card>

      <Modal
        title={editingMeter ? 'Editare Contor' : 'Adăugare Contor'}
        open={isModalOpen}
        onOk={handleOk}
        onCancel={() => {
          setIsModalOpen(false);
          setEditingMeter(null);
          form.resetFields();
        }}
        width={600}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={createMutation.isPending || updateMutation.isPending}
      >
        <Form
          form={form}
          layout="vertical"
          initialValues={{ is_active: true, is_general: false }}
        >
          <Form.Item
            label="Nume"
            name="name"
            rules={[{ required: true, message: 'Numele este obligatoriu' }]}
          >
            <Input placeholder="Ex: Contor Apartament 1" />
          </Form.Item>

          <Form.Item
            label="Chiriaș"
            name="tenant_id"
          >
            <Select placeholder="Selectați chiriașul" allowClear>
              {tenants.map((tenant) => (
                <Option key={tenant.id} value={tenant.id}>
                  {tenant.name}
                </Option>
              ))}
            </Select>
          </Form.Item>

          <Form.Item
            label="Locație"
            name="location"
          >
            <Input placeholder="Ex: Apartament 1, Etaj 2" />
          </Form.Item>

          <Form.Item
            label="Număr Serie"
            name="serial_number"
          >
            <Input />
          </Form.Item>

          <Form.Item
            label="Contor General"
            name="is_general"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>

          <Form.Item
            label="Activ"
            name="is_active"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default Meters;

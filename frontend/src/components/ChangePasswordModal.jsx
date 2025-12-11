import React, { useState } from 'react';
import { Modal, Form, Input, Button, message, Progress } from 'antd';
import { LockOutlined } from '@ant-design/icons';
import { authService } from '../services/authService';

const ChangePasswordModal = ({ visible, onClose }) => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [newPassword, setNewPassword] = useState('');

  // Password strength calculation
  const calculatePasswordStrength = (password) => {
    if (!password) return { score: 0, label: '', color: '' };

    let score = 0;

    // Length check
    if (password.length >= 8) score += 25;
    if (password.length >= 12) score += 15;

    // Character variety checks
    if (/[a-z]/.test(password)) score += 15;
    if (/[A-Z]/.test(password)) score += 15;
    if (/[0-9]/.test(password)) score += 15;
    if (/[^a-zA-Z0-9]/.test(password)) score += 15;

    // Determine label and color
    let label = '';
    let color = '';

    if (score < 40) {
      label = 'Slabă';
      color = '#ff4d4f';
    } else if (score < 60) {
      label = 'Medie';
      color = '#faad14';
    } else if (score < 80) {
      label = 'Bună';
      color = '#52c41a';
    } else {
      label = 'Foarte bună';
      color = '#1890ff';
    }

    return { score, label, color };
  };

  const passwordStrength = calculatePasswordStrength(newPassword);

  const handleSubmit = async (values) => {
    setLoading(true);
    try {
      await authService.changePassword(
        values.current_password,
        values.new_password
      );

      message.success('Parola a fost schimbată cu succes');
      form.resetFields();
      setNewPassword('');
      onClose();
    } catch (error) {
      console.error('Error changing password:', error);

      // Handle specific error messages
      if (error.response?.data?.message) {
        message.error(error.response.data.message);
      } else if (error.response?.status === 401) {
        message.error('Parola curentă este incorectă');
      } else if (error.response?.status === 400) {
        message.error('Datele introduse sunt invalide');
      } else {
        message.error('A apărut o eroare la schimbarea parolei');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = () => {
    form.resetFields();
    setNewPassword('');
    onClose();
  };

  return (
    <Modal
      title="Schimbă parola"
      open={visible}
      onCancel={handleCancel}
      footer={null}
      width={500}
      destroyOnHidden
    >
      <Form
        form={form}
        layout="vertical"
        onFinish={handleSubmit}
        autoComplete="off"
      >
        <Form.Item
          name="current_password"
          label="Parola curentă"
          rules={[
            {
              required: true,
              message: 'Vă rugăm introduceți parola curentă',
            },
          ]}
        >
          <Input.Password
            prefix={<LockOutlined />}
            placeholder="Introduceți parola curentă"
            size="large"
          />
        </Form.Item>

        <Form.Item
          name="new_password"
          label="Parola nouă"
          rules={[
            {
              required: true,
              message: 'Vă rugăm introduceți parola nouă',
            },
            {
              min: 8,
              message: 'Parola trebuie să conțină cel puțin 8 caractere',
            },
          ]}
        >
          <Input.Password
            prefix={<LockOutlined />}
            placeholder="Introduceți parola nouă"
            size="large"
            onChange={(e) => setNewPassword(e.target.value)}
          />
        </Form.Item>

        {newPassword && (
          <Form.Item>
            <div style={{ marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: '#8c8c8c' }}>
                Putere parolă: <span style={{ color: passwordStrength.color, fontWeight: 500 }}>
                  {passwordStrength.label}
                </span>
              </span>
            </div>
            <Progress
              percent={passwordStrength.score}
              strokeColor={passwordStrength.color}
              showInfo={false}
              size="small"
            />
          </Form.Item>
        )}

        <Form.Item
          name="confirm_password"
          label="Confirmă parola nouă"
          dependencies={['new_password']}
          rules={[
            {
              required: true,
              message: 'Vă rugăm confirmați parola nouă',
            },
            ({ getFieldValue }) => ({
              validator(_, value) {
                if (!value || getFieldValue('new_password') === value) {
                  return Promise.resolve();
                }
                return Promise.reject(new Error('Parolele nu se potrivesc'));
              },
            }),
          ]}
        >
          <Input.Password
            prefix={<LockOutlined />}
            placeholder="Confirmați parola nouă"
            size="large"
          />
        </Form.Item>

        <Form.Item style={{ marginBottom: 0, marginTop: 24 }}>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <Button onClick={handleCancel} disabled={loading}>
              Anulează
            </Button>
            <Button type="primary" htmlType="submit" loading={loading}>
              Schimbă parola
            </Button>
          </div>
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default ChangePasswordModal;

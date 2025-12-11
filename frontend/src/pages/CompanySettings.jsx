import React, { useEffect } from 'react';
import { Form, Input, Button, Card, message, Spin, Alert } from 'antd';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { companyService } from '../services/companyService';

const CompanySettings = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['company'],
    queryFn: companyService.get,
  });

  const updateMutation = useMutation({
    mutationFn: (values) => companyService.update(values),
    onSuccess: () => {
      message.success('Datele companiei au fost actualizate cu succes!');
      queryClient.invalidateQueries(['company']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizarea datelor');
    },
  });

  const createMutation = useMutation({
    mutationFn: (values) => companyService.create(values),
    onSuccess: () => {
      message.success('Datele companiei au fost create cu succes!');
      queryClient.invalidateQueries(['company']);
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la crearea datelor');
    },
  });

  useEffect(() => {
    if (data?.data?.company) {
      form.setFieldsValue(data.data.company);
    }
  }, [data, form]);

  const onFinish = (values) => {
    if (data?.data?.company) {
      updateMutation.mutate(values);
    } else {
      createMutation.mutate(values);
    }
  };

  if (isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '50px' }}>
        <Spin size="large" />
      </div>
    );
  }

  if (error && error.response?.status !== 404) {
    return (
      <Alert
        message="Eroare"
        description="Nu s-au putut încărca datele companiei"
        type="error"
        showIcon
      />
    );
  }

  return (
    <div>
      <h1 style={{ marginBottom: 24 }}>Setări Companie</h1>

      <Card>
        <Form
          form={form}
          layout="vertical"
          onFinish={onFinish}
          autoComplete="off"
        >
          <Form.Item
            label="Nume Companie"
            name="name"
            rules={[{ required: true, message: 'Numele companiei este obligatoriu' }]}
          >
            <Input placeholder="Ex: SC Example SRL" />
          </Form.Item>

          <Form.Item
            label="CUI/CIF"
            name="cui_cif"
            rules={[{ required: true, message: 'CUI/CIF este obligatoriu' }]}
          >
            <Input placeholder="Ex: RO12345678" />
          </Form.Item>

          <Form.Item
            label="Nr. Reg. Com."
            name="reg_com"
          >
            <Input placeholder="Ex: J12/1234/2020" />
          </Form.Item>

          <Form.Item
            label="Adresă"
            name="address"
            rules={[{ required: true, message: 'Adresa este obligatorie' }]}
          >
            <Input placeholder="Strada, număr" />
          </Form.Item>

          <Form.Item
            label="Oraș"
            name="city"
            rules={[{ required: true, message: 'Orașul este obligatoriu' }]}
          >
            <Input placeholder="Ex: Cluj-Napoca" />
          </Form.Item>

          <Form.Item
            label="Județ"
            name="county"
            rules={[{ required: true, message: 'Județul este obligatoriu' }]}
          >
            <Input placeholder="Ex: Cluj" />
          </Form.Item>

          <Form.Item
            label="Cod Poștal"
            name="postal_code"
          >
            <Input placeholder="Ex: 400001" />
          </Form.Item>

          <Form.Item
            label="Telefon"
            name="phone"
          >
            <Input placeholder="Ex: +40 123 456 789" />
          </Form.Item>

          <Form.Item
            label="Email"
            name="email"
            rules={[{ type: 'email', message: 'Email invalid' }]}
          >
            <Input placeholder="Ex: contact@example.com" />
          </Form.Item>

          <Form.Item
            label="Cont Bancar (IBAN)"
            name="bank_account"
          >
            <Input placeholder="Ex: RO49 AAAA 1B31 0075 9384 0000" />
          </Form.Item>

          <Form.Item
            label="Bancă"
            name="bank_name"
          >
            <Input placeholder="Ex: Banca Transilvania" />
          </Form.Item>

          <Form.Item
            label="Nume Reprezentant"
            name="representative_name"
          >
            <Input placeholder="Ex: Popescu Ion" />
          </Form.Item>

          <Form.Item>
            <Button
              type="primary"
              htmlType="submit"
              loading={updateMutation.isPending || createMutation.isPending}
            >
              Salvează
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default CompanySettings;

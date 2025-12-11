import React, { useEffect } from 'react';
import { Form, Input, Button, Card, message, Spin, Alert, Divider, Typography, Row, Col } from 'antd';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { profileService } from '../services/profileService';
import useAuthStore from '../stores/authStore';

const { Title, Text } = Typography;

const Profile = () => {
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const { updateUser } = useAuthStore();

  // Fetch profile data
  const { data, isLoading, error } = useQuery({
    queryKey: ['profile'],
    queryFn: profileService.get,
  });

  // Update mutation
  const updateMutation = useMutation({
    mutationFn: (values) => profileService.update(values),
    onSuccess: (response) => {
      message.success('Profilul a fost actualizat cu succes!');
      queryClient.invalidateQueries(['profile']);
      // Update user in auth store if user data changed
      if (response.data?.user) {
        updateUser(response.data.user);
      }
    },
    onError: (error) => {
      message.error(error.response?.data?.error || 'Eroare la actualizarea profilului');
    },
  });

  // Populate form when data is loaded
  useEffect(() => {
    if (data?.data) {
      const { user, company } = data.data;
      form.setFieldsValue({
        // Personal Information
        full_name: user?.full_name || '',
        id_series: user?.id_card_series || '',
        id_number: user?.id_card_number || '',
        id_issued_by: user?.id_card_issued_by || '',
        // Company Information
        company_name: company?.name || '',
        cui_cif: company?.cui_cif || '',
        reg_com: company?.j_number || '',
        address: company?.address || '',
        city: company?.city || '',
        county: company?.county || '',
        postal_code: company?.postal_code || '',
        phone: company?.phone || '',
        email: company?.email || '',
        bank_name: company?.bank_name || '',
        bank_account: company?.iban || '',
        // Invoice Settings
        invoice_prefix: company?.invoice_prefix || 'ARC',
        last_invoice_number: company?.last_invoice_number || 0,
      });
    }
  }, [data, form]);

  const onFinish = (values) => {
    // Transform flat form values to nested structure expected by backend
    const payload = {
      user: {
        full_name: values.full_name,
        id_card_series: values.id_series,
        id_card_number: values.id_number,
        id_card_issued_by: values.id_issued_by,
      },
      company: {
        name: values.company_name,
        cui_cif: values.cui_cif,
        j_number: values.reg_com,
        address: values.address,
        city: values.city,
        county: values.county,
        postal_code: values.postal_code,
        phone: values.phone,
        email: values.email,
        bank_name: values.bank_name,
        iban: values.bank_account,
        invoice_prefix: values.invoice_prefix?.toUpperCase(),
        last_invoice_number: parseInt(values.last_invoice_number) || 0,
      },
    };
    updateMutation.mutate(payload);
  };

  // Calculate next invoice number
  const invoicePrefix = Form.useWatch('invoice_prefix', form) || 'ARC';
  const lastInvoiceNumber = Form.useWatch('last_invoice_number', form) || 0;
  const nextInvoiceNumber = `${invoicePrefix}${(parseInt(lastInvoiceNumber) || 0) + 1}`;

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
        description="Nu s-au putut încărca datele profilului"
        type="error"
        showIcon
      />
    );
  }

  return (
    <div>
      <Title level={2} style={{ marginBottom: 24 }}>Profilul Meu</Title>

      <Form
        form={form}
        layout="vertical"
        onFinish={onFinish}
        autoComplete="off"
      >
        {/* Personal Information Section */}
        <Card title="Informații Personale" style={{ marginBottom: 24 }}>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Nume Complet"
                name="full_name"
                rules={[{ required: true, message: 'Numele complet este obligatoriu' }]}
              >
                <Input placeholder="Ex: Popescu Ion" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Serie C.I."
                name="id_series"
              >
                <Input placeholder="Ex: MZ" maxLength={2} style={{ textTransform: 'uppercase' }} />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Număr C.I."
                name="id_number"
              >
                <Input placeholder="Ex: 670173" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Eliberat de"
                name="id_issued_by"
              >
                <Input placeholder="Ex: SPCLEP Iași" />
              </Form.Item>
            </Col>
          </Row>
        </Card>

        {/* Company Information Section */}
        <Card title="Informații Firmă" style={{ marginBottom: 24 }}>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Nume Firmă"
                name="company_name"
                rules={[{ required: true, message: 'Numele firmei este obligatoriu' }]}
              >
                <Input placeholder="Ex: SC Example SRL" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="CUI/CIF"
                name="cui_cif"
                rules={[{ required: true, message: 'CUI/CIF este obligatoriu' }]}
              >
                <Input placeholder="Ex: RO12345678" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Nr. Registrul Comerțului"
                name="reg_com"
              >
                <Input placeholder="Ex: J12/1234/2020" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Cod Poștal"
                name="postal_code"
              >
                <Input placeholder="Ex: 400001" />
              </Form.Item>
            </Col>
          </Row>

          <Form.Item
            label="Adresă"
            name="address"
            rules={[{ required: true, message: 'Adresa este obligatorie' }]}
          >
            <Input placeholder="Strada, număr" />
          </Form.Item>

          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Oraș"
                name="city"
                rules={[{ required: true, message: 'Orașul este obligatoriu' }]}
              >
                <Input placeholder="Ex: Cluj-Napoca" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Județ"
                name="county"
                rules={[{ required: true, message: 'Județul este obligatoriu' }]}
              >
                <Input placeholder="Ex: Cluj" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Telefon"
                name="phone"
              >
                <Input placeholder="Ex: +40 123 456 789" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Email"
                name="email"
                rules={[{ type: 'email', message: 'Email invalid' }]}
              >
                <Input placeholder="Ex: contact@example.com" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Bancă"
                name="bank_name"
              >
                <Input placeholder="Ex: Banca Transilvania" />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="IBAN"
                name="bank_account"
              >
                <Input placeholder="Ex: RO49 AAAA 1B31 0075 9384 0000" />
              </Form.Item>
            </Col>
          </Row>
        </Card>

        {/* Invoice Settings Section */}
        <Card title="Setări Facturi" style={{ marginBottom: 24 }}>
          <Row gutter={16}>
            <Col xs={24} md={12}>
              <Form.Item
                label="Prefix Factură"
                name="invoice_prefix"
                rules={[{ required: true, message: 'Prefixul facturii este obligatoriu' }]}
              >
                <Input placeholder="Ex: ARC" style={{ textTransform: 'uppercase' }} maxLength={10} />
              </Form.Item>
            </Col>
            <Col xs={24} md={12}>
              <Form.Item
                label="Ultimul Număr Factură"
                name="last_invoice_number"
                rules={[{ required: true, message: 'Numărul facturii este obligatoriu' }]}
              >
                <Input type="number" min={0} placeholder="Ex: 0" />
              </Form.Item>
            </Col>
          </Row>

          <Alert
            message={
              <Text>
                Următoarea factură va fi: <Text strong>{nextInvoiceNumber}</Text>
              </Text>
            }
            type="info"
            showIcon
            style={{ marginTop: 8 }}
          />
        </Card>

        {/* Save Button */}
        <Form.Item>
          <Button
            type="primary"
            htmlType="submit"
            loading={updateMutation.isPending}
            size="large"
          >
            Salvează Modificările
          </Button>
        </Form.Item>
      </Form>
    </div>
  );
};

export default Profile;

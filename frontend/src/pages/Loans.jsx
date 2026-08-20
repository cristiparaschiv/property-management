import React, { useState } from 'react';
import {
  Card, Row, Col, Table, Button, Form, DatePicker, InputNumber, Input, Select,
  Space, Statistic, Progress, Popconfirm, message, Empty, Spin, Alert, Modal,
} from 'antd';
import { PlusOutlined, DeleteOutlined, SettingOutlined } from '@ant-design/icons';
import {
  ResponsiveContainer, AreaChart, Area, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip as RTooltip,
} from 'recharts';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import dayjs from 'dayjs';
import { loansService } from '../services/loansService';
import { formatCurrency, formatDate } from '../utils/formatters';

// Validated for contrast and colour-blind separation in both themes.
const DEBT = '#8e3b7a';
const PAID = '#1a7f4b';

const Loans = () => {
  const queryClient = useQueryClient();
  const [form] = Form.useForm();
  const [settingsForm] = Form.useForm();
  const [showSettings, setShowSettings] = useState(false);
  const [loanId, setLoanId] = useState(null);

  const { data: listData, isLoading: listLoading } = useQuery({
    queryKey: ['loans'],
    queryFn: loansService.getAll,
  });

  const loans = listData?.data?.loans || [];
  const activeId = loanId || loans[0]?.id;

  const { data: detail, isLoading: detailLoading } = useQuery({
    queryKey: ['loan', activeId],
    queryFn: () => loansService.getById(activeId),
    enabled: !!activeId,
  });

  const loan = detail?.data?.loan;
  const summary = detail?.data?.summary;
  const entries = detail?.data?.entries || [];
  const series = detail?.data?.series || [];

  const addMutation = useMutation({
    mutationFn: (values) => loansService.addEntry(activeId, values),
    onSuccess: () => {
      message.success('Înregistrare adăugată');
      form.resetFields();
      form.setFieldsValue({ entry_date: dayjs(), kind: 'payment' });
      queryClient.invalidateQueries({ queryKey: ['loan', activeId] });
      queryClient.invalidateQueries({ queryKey: ['loans'] });
    },
    onError: (e) => message.error(
      e?.response?.data?.error || 'Nu am putut adăuga înregistrarea'),
  });

  const deleteMutation = useMutation({
    mutationFn: (entryId) => loansService.deleteEntry(activeId, entryId),
    onSuccess: () => {
      message.success('Înregistrare ștearsă');
      queryClient.invalidateQueries({ queryKey: ['loan', activeId] });
      queryClient.invalidateQueries({ queryKey: ['loans'] });
    },
    onError: (e) => message.error(e?.response?.data?.error || 'Ștergere eșuată'),
  });

  const settingsMutation = useMutation({
    mutationFn: (values) => loansService.update(activeId, values),
    onSuccess: () => {
      message.success('Setări salvate');
      setShowSettings(false);
      queryClient.invalidateQueries({ queryKey: ['loan', activeId] });
    },
    onError: (e) => message.error(e?.response?.data?.error || 'Salvare eșuată'),
  });

  const handleAdd = (values) => {
    addMutation.mutate({
      entry_date: values.entry_date.format('YYYY-MM-DD'),
      kind: values.kind,
      amount: values.amount,
      label: values.label,
      note: values.note,
    });
  };

  const handleSettings = (values) => {
    settingsMutation.mutate({
      offset_label: values.offset_label,
      offset_rate: values.offset_rate,
      offset_start: values.offset_start ? values.offset_start.format('YYYY-MM-DD') : null,
    });
  };

  const openSettings = () => {
    settingsForm.setFieldsValue({
      offset_label: loan?.offset_label,
      offset_rate: Number(loan?.offset_rate || 0),
      offset_start: loan?.offset_start ? dayjs(loan.offset_start) : null,
    });
    setShowSettings(true);
  };

  if (listLoading) return <Spin size="large" style={{ display: 'block', margin: '4rem auto' }} />;
  if (!loans.length) {
    return <Card><Empty description="Niciun împrumut înregistrat" /></Card>;
  }

  const chartBalance = series.map((p) => ({
    date: p.entry_date,
    sold: Number(p.balance),
  }));
  const chartPayments = series
    .filter((p) => Number(p.amount) > 0)
    .map((p) => ({ date: p.entry_date, suma: Number(p.amount), label: p.label }));

  const columns = [
    {
      title: 'Data', dataIndex: 'entry_date', key: 'entry_date', width: 120,
      render: (d) => formatDate(d),
    },
    { title: 'Tranzacție', dataIndex: 'label', key: 'label' },
    {
      title: 'Sumă', dataIndex: 'amount', key: 'amount', align: 'right', width: 170,
      render: (a) => (
        <span style={{ color: Number(a) < 0 ? DEBT : PAID, fontWeight: 600 }}>
          {formatCurrency(a)}
        </span>
      ),
    },
    {
      title: '', key: 'actions', width: 60, align: 'right',
      render: (_, record) => (
        <Popconfirm
          title="Ștergi această înregistrare?"
          onConfirm={() => deleteMutation.mutate(record.id)}
          okText="Da" cancelText="Nu"
        >
          <Button type="text" danger size="small" icon={<DeleteOutlined />} />
        </Popconfirm>
      ),
    },
  ];

  return (
    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
      <Row justify="space-between" align="middle">
        <Col>
          <h2 style={{ margin: 0 }}>Împrumuturi</h2>
          {loans.length > 1 && (
            <Select
              value={activeId}
              onChange={setLoanId}
              style={{ minWidth: 200, marginTop: 8 }}
              options={loans.map((l) => ({ value: l.id, label: l.person }))}
            />
          )}
        </Col>
        <Col>
          <Button icon={<SettingOutlined />} onClick={openSettings} disabled={!loan}>
            Setări
          </Button>
        </Col>
      </Row>

      <Spin spinning={detailLoading}>
        {summary && (
          <>
            {/* The single number this page exists to answer. */}
            <Card>
              <Statistic
                title={`Rest de recuperat — ${loan?.person}`}
                value={Number(summary.net_owed)}
                precision={2}
                suffix={summary.currency}
                valueStyle={{ color: DEBT, fontSize: 34, fontWeight: 650 }}
              />
              <div style={{ marginTop: 8, color: '#888', fontSize: 13 }}>
                {formatCurrency(summary.outstanding)} sold împrumut
                {Number(summary.offset_total) > 0 && (
                  <> &minus; {formatCurrency(summary.offset_total)}{' '}
                    {(summary.offset_label || '').toLowerCase()}{' '}
                    ({summary.offset_months} luni × {formatCurrency(summary.offset_rate)})</>
                )}
              </div>
            </Card>

            <Row gutter={[12, 12]}>
              <Col xs={12} md={6}>
                <Card size="small"><Statistic title="Împrumutat"
                  value={Number(summary.lent)} precision={2} /></Card>
              </Col>
              <Col xs={12} md={6}>
                <Card size="small"><Statistic title="Recuperat"
                  value={Number(summary.repaid)} precision={2}
                  valueStyle={{ color: PAID }} /></Card>
              </Col>
              <Col xs={12} md={6}>
                <Card size="small"><Statistic title="Sold împrumut"
                  value={Number(summary.outstanding)} precision={2} /></Card>
              </Col>
              <Col xs={12} md={6}>
                <Card size="small"><Statistic title="Ritm lunar"
                  value={Number(summary.monthly_pace)} precision={2} /></Card>
              </Col>
            </Row>

            <Card size="small">
              <Progress
                percent={Number(summary.pct_repaid)}
                strokeColor={PAID}
                format={(p) => `${Math.round(p)}%`}
              />
              <div style={{ color: '#888', fontSize: 13 }}>
                {Math.round(Number(summary.pct_repaid))}% recuperat din{' '}
                {formatCurrency(summary.lent)}
                {summary.projected_payoff && (
                  <> · la ritmul actual, achitat pe la {dayjs(summary.projected_payoff).format('MM.YYYY')}</>
                )}
              </div>
            </Card>
          </>
        )}

        <Row gutter={[12, 12]} style={{ marginTop: 12 }}>
          <Col xs={24} lg={14}>
            <Card size="small" title="Sold în timp">
              {/* Stepped: a balance changes on the day of a movement, not
                  gradually across the gap between them. */}
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={chartBalance} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="date" tickFormatter={(d) => dayjs(d).format('MM.YY')}
                         fontSize={11} minTickGap={24} />
                  <YAxis tickFormatter={(v) => `${Math.round(v / 1000)}k`} fontSize={11} width={44} />
                  <RTooltip formatter={(v) => formatCurrency(v)}
                            labelFormatter={(d) => formatDate(d)} />
                  <Area type="stepAfter" dataKey="sold" name="Sold"
                        stroke={DEBT} strokeWidth={2} fill={DEBT} fillOpacity={0.12} />
                </AreaChart>
              </ResponsiveContainer>
            </Card>
          </Col>
          <Col xs={24} lg={10}>
            <Card size="small" title="Rambursări">
              <ResponsiveContainer width="100%" height={260}>
                <BarChart data={chartPayments} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="date" tickFormatter={(d) => dayjs(d).format('MM.YY')}
                         fontSize={11} minTickGap={16} />
                  <YAxis tickFormatter={(v) => `${Math.round(v / 1000)}k`} fontSize={11} width={44} />
                  <RTooltip formatter={(v) => formatCurrency(v)}
                            labelFormatter={(d) => formatDate(d)} />
                  <Bar dataKey="suma" name="Plată" fill={PAID} radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </Card>
          </Col>
        </Row>

        <Card size="small" title="Adaugă" style={{ marginTop: 12 }}>
          <Form form={form} layout="inline" onFinish={handleAdd}
                initialValues={{ entry_date: dayjs(), kind: 'payment' }}>
            <Form.Item name="entry_date" label="Data" rules={[{ required: true }]}>
              <DatePicker format="DD.MM.YYYY" />
            </Form.Item>
            <Form.Item name="kind" label="Tip">
              <Select style={{ width: 170 }} options={[
                { value: 'payment', label: 'Plată primită' },
                { value: 'advance', label: 'Împrumut acordat' },
              ]} />
            </Form.Item>
            <Form.Item name="amount" label="Sumă"
                       rules={[{ required: true, message: 'Suma este obligatorie' }]}>
              <InputNumber min={0.01} step={100} style={{ width: 140 }} placeholder="10000" />
            </Form.Item>
            <Form.Item name="label" label="Descriere">
              <Input placeholder="Cash, Revolut…" style={{ width: 180 }} />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" icon={<PlusOutlined />}
                      loading={addMutation.isPending}>
                Adaugă
              </Button>
            </Form.Item>
          </Form>
          <div style={{ color: '#888', fontSize: 12, marginTop: 8 }}>
            Suma se scrie pozitiv în ambele cazuri — tipul decide semnul.
          </div>
        </Card>

        <Card size="small" title={`Mișcări (${entries.length})`} style={{ marginTop: 12 }}>
          <Table
            rowKey="id"
            columns={columns}
            dataSource={entries}
            size="small"
            pagination={{ pageSize: 20, hideOnSinglePage: true }}
          />
        </Card>
      </Spin>

      {/* A modal, not an inline panel: the button sits above the fold and the
          entries table below it is long, so a panel appended at the end of the
          page opened out of sight and read as a dead button. */}
      <Modal
        title="Setări — compensare lunară"
        open={showSettings}
        onCancel={() => setShowSettings(false)}
        onOk={() => settingsForm.submit()}
        okText="Salvează"
        cancelText="Anulează"
        confirmLoading={settingsMutation.isPending}
        destroyOnClose
      >
        <Alert
          type="info" showIcon style={{ marginBottom: 16 }}
          message="Se acumulează automat până în luna curentă. Pune 0 ca să dezactivezi."
        />
        <Form form={settingsForm} layout="vertical" onFinish={handleSettings}>
          <Form.Item name="offset_label" label="Denumire">
            <Input placeholder="Servicii contabile" />
          </Form.Item>
          <Form.Item name="offset_rate" label="RON / lună">
            <InputNumber min={0} step={50} style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="offset_start" label="Începând cu">
            <DatePicker format="DD.MM.YYYY" style={{ width: '100%' }} />
          </Form.Item>
        </Form>
      </Modal>
    </Space>
  );
};

export default Loans;

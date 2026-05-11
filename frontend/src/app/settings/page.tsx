'use client';

import { useState } from 'react';
import {
  Plus,
  Pencil,
  Trash2,
  Plug,
  Loader2,
  CheckCircle2,
  XCircle,
  BrainCircuit,
  FileText,
  Power,
  Check,
  X,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { ProviderForm } from '@/components/provider-form';
import { ProviderCardSkeleton } from '@/components/skeletons';
import {
  useProviders,
  useCreateProvider,
  useUpdateProvider,
  useDeleteProvider,
  useTestProvider,
  useCreateModel,
  useUpdateModel,
  useDeleteModel,
  usePromptTemplates,
  useCreatePromptTemplate,
  useActivatePromptTemplate,
} from '@/lib/api';
import type {
  AIModel,
  AIProvider,
  CreateModelRequest,
  CreateProviderRequest,
  UpdateProviderRequest,
  PromptTemplate,
} from '@/types';
import { toast } from 'sonner';
import { cn } from '@/lib/utils';

function ProviderModels({ provider }: { provider: AIProvider }) {
  const createModel = useCreateModel();
  const updateModel = useUpdateModel();
  const deleteModel = useDeleteModel();
  const [editing, setEditing] = useState<AIModel | null>(null);
  const [modelName, setModelName] = useState('');
  const [temperature, setTemperature] = useState('0.3');
  const [maxTokens, setMaxTokens] = useState('4096');
  const [isDefault, setIsDefault] = useState(false);

  const resetForm = () => {
    setEditing(null);
    setModelName('');
    setTemperature('0.3');
    setMaxTokens('4096');
    setIsDefault(false);
  };

  const startEdit = (model: AIModel) => {
    setEditing(model);
    setModelName(model.model_name);
    setTemperature(String(model.temperature));
    setMaxTokens(String(model.max_tokens));
    setIsDefault(model.is_default);
  };

  const submitModel = () => {
    const payload: CreateModelRequest = {
      model_name: modelName.trim(),
      temperature: Number(temperature),
      max_tokens: Number(maxTokens),
      is_default: isDefault,
    };
    if (!payload.model_name) {
      toast.error('请填写模型名称');
      return;
    }

    if (editing) {
      updateModel.mutate(
        { providerId: provider.id, modelId: editing.id, data: payload },
        {
          onSuccess: () => {
            toast.success('模型已更新');
            resetForm();
          },
          onError: (err) => toast.error(`更新失败: ${err.message}`),
        }
      );
      return;
    }

    createModel.mutate(
      { providerId: provider.id, data: payload },
      {
        onSuccess: () => {
          toast.success('模型已添加');
          resetForm();
        },
        onError: (err) => toast.error(`添加失败: ${err.message}`),
      }
    );
  };

  const isSaving = createModel.isPending || updateModel.isPending;

  return (
    <div className="space-y-3 border-t pt-3">
      <div className="space-y-2">
        {provider.models.length > 0 ? (
          provider.models.map((model) => (
            <div key={model.id} className="flex items-center gap-2 rounded-md bg-muted/40 px-2 py-1.5">
              <Badge variant={model.is_default ? 'default' : 'outline'} className="text-[11px]">
                {model.model_name}
              </Badge>
              <span className="text-[11px] text-muted-foreground">
                {model.temperature} / {model.max_tokens}
              </span>
              <div className="ml-auto flex gap-1">
                {!model.is_default && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-7 px-2"
                    onClick={() =>
                      updateModel.mutate(
                        {
                          providerId: provider.id,
                          modelId: model.id,
                          data: { is_default: true },
                        },
                        {
                          onSuccess: () => toast.success('已设为默认模型'),
                          onError: (err) => toast.error(`设置失败: ${err.message}`),
                        }
                      )
                    }
                  >
                    <Check className="h-3.5 w-3.5" />
                  </Button>
                )}
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2"
                  onClick={() => startEdit(model)}
                >
                  <Pencil className="h-3.5 w-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-destructive hover:bg-destructive/10 hover:text-destructive"
                  onClick={() =>
                    deleteModel.mutate(
                      { providerId: provider.id, modelId: model.id },
                      {
                        onSuccess: () => toast.success('模型已删除'),
                        onError: (err) => toast.error(`删除失败: ${err.message}`),
                      }
                    )
                  }
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </Button>
              </div>
            </div>
          ))
        ) : (
          <p className="text-xs text-muted-foreground">暂未配置模型</p>
        )}
      </div>

      <div className="grid gap-2">
        <Input
          value={modelName}
          onChange={(e) => setModelName(e.target.value)}
          placeholder="模型名称，例如 gpt-4o-mini"
          className="h-8 text-xs"
        />
        <div className="grid grid-cols-2 gap-2">
          <Input
            type="number"
            step="0.1"
            value={temperature}
            onChange={(e) => setTemperature(e.target.value)}
            placeholder="Temperature"
            className="h-8 text-xs"
          />
          <Input
            type="number"
            value={maxTokens}
            onChange={(e) => setMaxTokens(e.target.value)}
            placeholder="Max tokens"
            className="h-8 text-xs"
          />
        </div>
        <div className="flex items-center justify-between gap-2">
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            <input
              type="checkbox"
              checked={isDefault}
              onChange={(e) => setIsDefault(e.target.checked)}
              className="h-3.5 w-3.5 rounded border-input"
            />
            设为默认
          </label>
          <div className="flex gap-2">
            {editing && (
              <Button variant="ghost" size="sm" className="h-8" onClick={resetForm}>
                <X className="h-3.5 w-3.5" />
              </Button>
            )}
            <Button size="sm" className="h-8" onClick={submitModel} disabled={isSaving}>
              {isSaving && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
              {editing ? '保存模型' : '添加模型'}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function SettingsPage() {
  const { data: providers, isLoading } = useProviders();
  const createMut = useCreateProvider();
  const updateMut = useUpdateProvider();
  const deleteMut = useDeleteProvider();
  const testMut = useTestProvider();

  const [formOpen, setFormOpen] = useState(false);
  const [editingProvider, setEditingProvider] = useState<AIProvider | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<AIProvider | null>(null);

  const handleCreate = () => {
    setEditingProvider(null);
    setFormOpen(true);
  };

  const handleEdit = (provider: AIProvider) => {
    setEditingProvider(provider);
    setFormOpen(true);
  };

  const handleDelete = (provider: AIProvider) => {
    setDeleteTarget(provider);
  };

  const confirmDelete = () => {
    if (!deleteTarget) return;
    deleteMut.mutate(deleteTarget.id, {
      onSuccess: () => toast.success('已删除提供商'),
      onError: (err) => toast.error(`删除失败: ${err.message}`),
      onSettled: () => setDeleteTarget(null),
    });
  };

  const handleFormSubmit = (
    data: CreateProviderRequest | UpdateProviderRequest
  ) => {
    if (editingProvider) {
      updateMut.mutate(
        { id: editingProvider.id, data: data as UpdateProviderRequest },
        {
          onSuccess: () => {
            toast.success('提供商已更新');
            setFormOpen(false);
          },
          onError: (err) => toast.error(`更新失败: ${err.message}`),
        }
      );
    } else {
      createMut.mutate(data as CreateProviderRequest, {
        onSuccess: () => {
          toast.success('提供商已添加');
          setFormOpen(false);
        },
        onError: (err) => toast.error(`添加失败: ${err.message}`),
      });
    }
  };

  const handleTest = (id: string) => {
    testMut.mutate(id, {
      onSuccess: (result) => {
        if (result.success) {
          toast.success(`连接成功: ${result.message}`);
        } else {
          toast.error(`连接失败: ${result.message}`);
        }
      },
      onError: (err) => toast.error(`测试失败: ${err.message}`),
    });
  };

  // ===== Prompt Templates =====
  const { data: promptData, isLoading: promptsLoading } = usePromptTemplates();
  const createPromptMut = useCreatePromptTemplate();
  const activatePromptMut = useActivatePromptTemplate();

  const [promptDialogOpen, setPromptDialogOpen] = useState(false);
  const [promptName, setPromptName] = useState('');
  const [promptContent, setPromptContent] = useState('');

  const handleOpenPromptDialog = () => {
    setPromptName('');
    setPromptContent('');
    setPromptDialogOpen(true);
  };

  const handleCreatePrompt = (e: React.FormEvent) => {
    e.preventDefault();
    if (!promptName.trim() || !promptContent.trim()) return;
    createPromptMut.mutate(
      { name: promptName.trim(), content: promptContent.trim() },
      {
        onSuccess: () => {
          toast.success('Prompt 模板已创建');
          setPromptDialogOpen(false);
        },
        onError: (err) => toast.error(`创建失败: ${err.message}`),
      }
    );
  };

  const handleActivate = (id: string) => {
    activatePromptMut.mutate(id, {
      onSuccess: () => toast.success('已激活该 Prompt 模板'),
      onError: (err) => toast.error(`激活失败: ${err.message}`),
    });
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">设置</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            管理 AI 提供商、模型配置和 Prompt 模板
          </p>
        </div>
        <Button size="sm" onClick={handleCreate}>
          <Plus className="mr-1.5 h-3.5 w-3.5" />
          添加提供商
        </Button>
      </div>

      {/* Provider List */}
      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <ProviderCardSkeleton key={i} />
          ))}
        </div>
      ) : providers?.items.length ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {providers.items.map((provider) => (
            <Card
              key={provider.id}
              className="overflow-hidden transition-all duration-200 hover:shadow-md hover:border-primary/20"
            >
              <CardContent className="p-5 space-y-4">
                {/* Header */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2.5">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10">
                      <BrainCircuit className="h-4 w-4 text-primary" />
                    </div>
                    <div>
                      <h3 className="text-sm font-semibold">{provider.name}</h3>
                    </div>
                  </div>
                  {provider.is_active && (
                    <Badge variant="secondary" className="text-[11px]">
                      活跃
                    </Badge>
                  )}
                </div>

                {/* Details */}
                <div className="space-y-2 text-sm">
                  <div>
                    <p className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">
                      Base URL
                    </p>
                    <p className="mt-0.5 truncate text-xs text-foreground/80 font-mono">
                      {provider.base_url}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-medium text-muted-foreground uppercase tracking-wide">
                      API Key
                    </p>
                    <p className="mt-0.5 text-xs text-foreground/60 font-mono">
                      sk-{'*'.repeat(20)}
                    </p>
                  </div>
                </div>

                {/* Models */}
                {provider.models.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {provider.models.map((model) => (
                      <Badge
                        key={model.id}
                        variant={model.is_default ? 'default' : 'outline'}
                        className="text-[11px]"
                      >
                        {model.model_name}
                      </Badge>
                    ))}
                  </div>
                )}

                {/* Test result */}
                {testMut.data && testMut.variables === provider.id && (
                  <div
                    className={cn(
                      'flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs',
                      testMut.data.success
                        ? 'bg-green-500/10 text-green-700 dark:text-green-400'
                        : 'bg-red-500/10 text-red-700 dark:text-red-400'
                    )}
                  >
                    {testMut.data.success ? (
                      <CheckCircle2 className="h-3.5 w-3.5" />
                    ) : (
                      <XCircle className="h-3.5 w-3.5" />
                    )}
                    {testMut.data.message}
                  </div>
                )}

                {/* Actions */}
                <div className="flex gap-2 pt-1 border-t">
                  <Button
                    variant="outline"
                    size="sm"
                    className="flex-1 h-8"
                    onClick={() => handleTest(provider.id)}
                    disabled={testMut.isPending && testMut.variables === provider.id}
                  >
                    {testMut.isPending && testMut.variables === provider.id ? (
                      <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                    ) : (
                      <Plug className="mr-1.5 h-3.5 w-3.5" />
                    )}
                    测试连接
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 p-0"
                    onClick={() => handleEdit(provider)}
                  >
                    <Pencil className="h-3.5 w-3.5" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 p-0 text-destructive hover:bg-destructive/10 hover:text-destructive"
                    onClick={() => handleDelete(provider)}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </Button>
                </div>

                <ProviderModels provider={provider} />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <Card className="border-dashed">
          <CardContent className="flex flex-col items-center justify-center py-20">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-muted">
              <BrainCircuit className="h-7 w-7 text-muted-foreground" />
            </div>
            <h3 className="mt-4 text-sm font-medium">暂未配置 AI 提供商</h3>
            <p className="mt-1 text-xs text-muted-foreground text-center max-w-[260px]">
              添加 AI 提供商以启用转录和智能总结功能
            </p>
            <Button className="mt-5" size="sm" onClick={handleCreate}>
              <Plus className="mr-1.5 h-3.5 w-3.5" />
              添加提供商
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Provider Form Dialog */}
      <ProviderForm
        open={formOpen}
        onOpenChange={setFormOpen}
        provider={editingProvider}
        onSubmit={handleFormSubmit}
        isSubmitting={createMut.isPending || updateMut.isPending}
      />

      {/* Prompt Templates Section */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold tracking-tight">Prompt 模板</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              管理智能总结使用的 Prompt 模板版本
            </p>
          </div>
          <Button size="sm" onClick={handleOpenPromptDialog}>
            <Plus className="mr-1.5 h-3.5 w-3.5" />
            新建 Prompt
          </Button>
        </div>

        {promptsLoading ? (
          <Card>
            <CardContent className="flex items-center justify-center py-10">
              <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
            </CardContent>
          </Card>
        ) : promptData?.items && promptData.items.length > 0 ? (
          <Card>
            <CardContent className="p-0">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[240px]">名称</TableHead>
                    <TableHead className="w-[100px] text-center">版本</TableHead>
                    <TableHead className="w-[100px] text-center">状态</TableHead>
                    <TableHead className="text-right">操作</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {promptData.items.map((tpl: PromptTemplate) => (
                    <TableRow key={tpl.id}>
                      <TableCell className="font-medium">{tpl.name}</TableCell>
                      <TableCell className="text-center text-muted-foreground">
                        v{tpl.version}
                      </TableCell>
                      <TableCell className="text-center">
                        {tpl.is_active ? (
                          <Badge variant="default" className="text-[11px]">
                            使用中
                          </Badge>
                        ) : (
                          <Badge variant="outline" className="text-[11px]">
                            未激活
                          </Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        {!tpl.is_active && (
                          <Button
                            variant="outline"
                            size="sm"
                            className="h-7 text-xs"
                            disabled={
                              activatePromptMut.isPending &&
                              activatePromptMut.variables === tpl.id
                            }
                            onClick={() => handleActivate(tpl.id)}
                          >
                            {activatePromptMut.isPending &&
                            activatePromptMut.variables === tpl.id ? (
                              <Loader2 className="mr-1.5 h-3 w-3 animate-spin" />
                            ) : (
                              <Power className="mr-1.5 h-3 w-3" />
                            )}
                            激活
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        ) : (
          <Card className="border-dashed">
            <CardContent className="flex flex-col items-center justify-center py-16">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-muted">
                <FileText className="h-7 w-7 text-muted-foreground" />
              </div>
              <h3 className="mt-4 text-sm font-medium">暂无 Prompt 模板</h3>
              <p className="mt-1 text-xs text-muted-foreground text-center max-w-[260px]">
                创建 Prompt 模板以自定义智能总结的内容生成方式
              </p>
              <Button className="mt-5" size="sm" onClick={handleOpenPromptDialog}>
                <Plus className="mr-1.5 h-3.5 w-3.5" />
                新建 Prompt
              </Button>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Create Prompt Dialog */}
      <Dialog open={promptDialogOpen} onOpenChange={setPromptDialogOpen}>
        <DialogContent className="sm:max-w-[600px]">
          <DialogHeader>
            <DialogTitle>新建 Prompt 模板</DialogTitle>
            <DialogDescription>
              创建新的 Prompt 模板，将作为新版本保存
            </DialogDescription>
          </DialogHeader>
          <form onSubmit={handleCreatePrompt} className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">模板名称</label>
              <Input
                value={promptName}
                onChange={(e) => setPromptName(e.target.value)}
                placeholder="例如: 默认总结模板"
                required
              />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Prompt 内容</label>
              <Textarea
                value={promptContent}
                onChange={(e) => setPromptContent(e.target.value)}
                placeholder="请输入 Prompt 模板内容..."
                className="min-h-[200px] font-mono text-sm"
                required
              />
            </div>
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setPromptDialogOpen(false)}
              >
                取消
              </Button>
              <Button
                type="submit"
                disabled={
                  createPromptMut.isPending ||
                  !promptName.trim() ||
                  !promptContent.trim()
                }
              >
                {createPromptMut.isPending && (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                )}
                创建
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete Provider Dialog */}
      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent className="sm:max-w-[380px]">
          <DialogHeader>
            <DialogTitle>删除提供商</DialogTitle>
            <DialogDescription>
              删除后会同时移除此提供商下的模型配置。
            </DialogDescription>
          </DialogHeader>
          <p className="text-sm">
            确定删除 <span className="font-medium">{deleteTarget?.name}</span> 吗？
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>
              取消
            </Button>
            <Button variant="destructive" onClick={confirmDelete} disabled={deleteMut.isPending}>
              {deleteMut.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
              删除
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

"""AI模型配置的Pydantic模式定义"""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.domains.ai.models import ModelType


# 基础模式
class AIModelConfigBase(BaseModel):
    """AI模型配置基础模式"""

    name: str = Field(..., min_length=1, max_length=100, description="模型名称")
    display_name: str = Field(..., min_length=1, max_length=200, description="显示名称")
    description: str | None = Field(None, description="模型描述")
    model_type: ModelType = Field(..., description="模型类型")
    api_url: str = Field(..., min_length=1, max_length=500, description="API端点URL")
    api_key: str | None = Field(None, max_length=500, description="API密钥")
    model_id: str = Field(..., min_length=1, max_length=200, description="模型标识符")
    provider: str = Field(default="custom", max_length=100, description="提供商")
    max_tokens: int | None = Field(None, gt=0, description="最大令牌数")
    temperature: str | None = Field(None, description="温度参数")
    timeout_seconds: int = Field(default=300, gt=0, description="请求超时时间（秒）")
    max_concurrent_requests: int = Field(default=1, gt=0, description="最大并发请求数")
    extra_config: dict[str, Any] | None = Field(
        default_factory=dict, description="额外配置参数"
    )
    is_active: bool = Field(default=True, description="是否启用")
    is_default: bool = Field(default=False, description="是否为默认模型")

    @field_validator("temperature")
    @classmethod
    def validate_temperature(cls, v):
        if v is not None:
            try:
                temp = float(v)
                if not 0 <= temp <= 2:
                    raise ValueError("温度参数必须在0-2之间")
            except ValueError as err:
                raise ValueError("温度参数必须是数字") from err
        return v


# 请求模式
class AIModelConfigCreate(AIModelConfigBase):
    """创建AI模型配置请求模式"""


class AIModelConfigUpdate(BaseModel):
    """更新AI模型配置请求模式"""

    display_name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    api_url: str | None = Field(None, min_length=1, max_length=500)
    api_key: str | None = Field(None, max_length=500)
    model_id: str | None = Field(None, min_length=1, max_length=200)
    max_tokens: int | None = Field(None, gt=0)
    temperature: str | None = None
    timeout_seconds: int | None = Field(None, gt=0)
    max_concurrent_requests: int | None = Field(None, gt=0)
    extra_config: dict[str, Any] | None = None
    is_active: bool | None = None
    is_default: bool | None = None

    @field_validator("temperature")
    @classmethod
    def validate_temperature(cls, v):
        if v is not None:
            try:
                temp = float(v)
                if not 0 <= temp <= 2:
                    raise ValueError("温度参数必须在0-2之间")
            except ValueError as err:
                raise ValueError("温度参数必须是数字") from err
        return v


# 响应模式
class AIModelConfigResponse(AIModelConfigBase):
    """AI模型配置响应模式"""

    id: int
    api_key_encrypted: bool
    usage_count: int
    success_count: int
    error_count: int
    total_tokens_used: int
    success_rate: float = 0.0  # 默认值，避免from_orm失败
    created_at: datetime
    updated_at: datetime
    last_used_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class AIModelConfigList(BaseModel):
    """AI模型配置列表响应模式"""

    models: list[AIModelConfigResponse]
    total: int
    page: int
    size: int
    pages: int


# 统计模式
class ModelUsageStats(BaseModel):
    """模型使用统计模式"""

    model_id: int
    model_name: str
    model_type: str
    usage_count: int
    success_count: int
    error_count: int
    success_rate: float
    total_tokens_used: int
    last_used_at: datetime | None
    total_cost: float | None = None


# 测试模式
class ModelTestRequest(BaseModel):
    """模型测试请求模式"""

    model_id: int
    test_data: dict[str, Any] | None = Field(default=dict, description="测试数据")


class ModelTestResponse(BaseModel):
    """模型测试响应模式"""

    success: bool
    response_time_ms: float
    result: str | None = None
    error_message: str | None = None


# 导出配置
class APIKeyValidationRequest(BaseModel):
    """API密钥验证请求"""

    api_url: str
    api_key: str
    model_id: str | None = None
    model_type: ModelType


class APIKeyValidationResponse(BaseModel):
    """API密钥验证响应"""

    valid: bool
    error_message: str | None = None
    test_result: str | None = None
    response_time_ms: float

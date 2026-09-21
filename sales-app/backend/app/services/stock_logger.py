from sqlalchemy.orm import Session
from uuid import UUID, uuid4
from app.models.models import StokLog


def log_stock_change(
    db: Session,
    product_id: str,
    sumber: str,
    field_terdampak: str,
    delta: int,
    nilai_sebelum: int,
    nilai_sesudah: int,
    actor_id: UUID | None = None,
    order_id: UUID | None = None,
) -> StokLog:
    log_entry = StokLog(
        id=uuid4(),
        product_id=product_id,
        sumber=sumber,
        field_terdampak=field_terdampak,
        delta=delta,
        nilai_sebelum=nilai_sebelum,
        nilai_sesudah=nilai_sesudah,
        actor_id=actor_id,
        order_id=order_id,
    )
    db.add(log_entry)
    return log_entry

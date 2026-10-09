BRANCH_CODES = ["BANJARMASIN", "BATULICIN", "BARABAI", "PALANGKARAYA", "SAMPIT"]
BRANCH_LABELS = {
    "BANJARMASIN": "Cabang Banjarmasin",
    "BATULICIN": "Cabang Batulicin",
    "BARABAI": "Cabang Barabai",
    "PALANGKARAYA": "Cabang Palangkaraya",
    "SAMPIT": "Cabang Sampit",
}
ROLE_LABELS = {
    "ADMIN": "Admin",
    "SUPERVISOR": "Supervisor",
    "MANAGER": "Manager",
    "SALES": "Sales",
}


def is_valid_branch(code: str) -> bool:
    return code in BRANCH_CODES

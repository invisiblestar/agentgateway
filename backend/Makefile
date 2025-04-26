.PHONY: run test clean

run:
	PYTHONDONTWRITEBYTECODE=1 python -B -m uvicorn app.main:app --reload

test:
	PYTHONDONTWRITEBYTECODE=1 python -B -m pytest

clean:
	find . -type d -name "__pycache__" -exec rm -r {} +
	find . -type f -name "*.pyc" -delete 
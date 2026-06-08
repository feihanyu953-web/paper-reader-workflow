"""
paper_fetcher.py — 连接已有浏览器，自动搜索+下载论文

前提：用桌面上的 [Edge (调试模式)] 快捷方式打开浏览器。
用法（由 Claude Code 调用）：
  python paper_fetcher.py search "TiO2 carbon hydrothermal" --limit 10
  python paper_fetcher.py download results.json --output ./pdfs
"""

import argparse
import json
import random
import re
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


CDP_URL = "http://localhost:9222"


# ── 工具 ──────────────────────────────────────────────────────────

def human_delay(lo=2.0, hi=5.0):
    time.sleep(random.uniform(lo, hi))

def safe_filename(title: str, max_len=80) -> str:
    name = re.sub(r'[\\/*?:"<>|]', '', title).strip()
    name = re.sub(r'\s+', '_', name)
    return name[:max_len] if name else "untitled"


# ── 浏览器连接 ────────────────────────────────────────────────────

def connect_browser():
    """连接到已运行的 Edge 浏览器（通过 CDP），使用当前活动标签页"""
    from playwright.sync_api import sync_playwright
    import requests

    # 验证调试端口
    try:
        r = requests.get(f"{CDP_URL}/json/version", timeout=5)
        info = r.json()
        print(f"已连接: {info.get('Browser', 'unknown')}")
    except Exception:
        print("错误: Edge 调试端口未就绪。")
        print("请用桌面上的 [Edge (调试模式)] 快捷方式打开浏览器。")
        sys.exit(1)

    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP_URL)
    context = browser.contexts[0] if browser.contexts else browser.new_context()

    # 使用已有的页面（用户当前打开的标签页），而不是创建新页面
    if context.pages:
        page = context.pages[-1]  # 最后一个页面（最活跃的）
        print(f"使用当前标签页: {page.url[:80]}")
    else:
        page = context.new_page()

    return pw, browser, context, page


# ── Google Scholar 搜索 ───────────────────────────────────────────

def search_google_scholar(page, query: str, limit: int = 20) -> list[dict]:
    print(f"[Google Scholar] 搜索: {query}")
    url = f"https://scholar.google.com/scholar?q={query}&hl=en&num={limit}"
    page.goto(url, wait_until="domcontentloaded", timeout=30000)
    human_delay(3, 6)

    if "sorry" in page.url.lower() or page.query_selector("#captcha"):
        print("  需要验证码，请在浏览器中手动完成...")
        input("  完成后按 Enter...")

    results = []
    entries = page.query_selector_all(".gs_r.gs_or.gs_scl")

    for entry in entries[:limit]:
        try:
            title_el = entry.query_selector(".gs_rt a") or entry.query_selector(".gs_rt")
            title = title_el.inner_text().strip() if title_el else ""
            link = title_el.get_attribute("href") if title_el else ""

            meta_el = entry.query_selector(".gs_a")
            meta_text = meta_el.inner_text().strip() if meta_el else ""
            authors, year, venue = _parse_scholar_meta(meta_text)

            abs_el = entry.query_selector(".gs_rs")
            abstract = abs_el.inner_text().strip() if abs_el else ""

            cit_el = entry.query_selector('a[href*="cites"]')
            cit_text = cit_el.inner_text() if cit_el else "0"
            cit_count = int(re.search(r'\d+', cit_text).group()) if re.search(r'\d+', cit_text) else 0

            pdf_el = entry.query_selector('a[href*=".pdf"]')
            pdf_url = pdf_el.get_attribute("href") if pdf_el else ""

            doi = _extract_doi(link) if link else ""

            results.append({
                "title": title, "authors": authors, "year": year,
                "abstract": abstract, "doi": doi, "venue": venue,
                "citation_count": cit_count, "source": "google_scholar",
                "url": link, "pdf_url": pdf_url,
            })
        except Exception:
            continue

    print(f"  找到 {len(results)} 篇")
    return results


def _parse_scholar_meta(text: str):
    authors, year, venue = [], None, ""
    parts = text.split(" - ")
    if parts:
        authors = [a.strip() for a in parts[0].strip().rstrip(",").split(",") if a.strip()]
    if len(parts) > 1:
        m = re.search(r'(\d{4})', parts[1])
        if m: year = int(m.group(1))
    if len(parts) > 2:
        venue = parts[2].strip().rstrip(",")
    return authors, year, venue


# ── Web of Science 搜索 ───────────────────────────────────────────

def search_wos(page, query: str, limit: int = 20) -> list[dict]:
    """在 Web of Science 中搜索（需已在校园网登录）"""
    print(f"[Web of Science] 搜索: {query}")

    # 导航到 WoS
    page.goto("https://www.webofscience.com/wos/woscc/basic-search", wait_until="load", timeout=60000)
    # 等待页面完全加载（WoS 是 SPA，需要额外等待 JS 渲染）
    page.wait_for_load_state("networkidle", timeout=30000)
    human_delay(3, 5)

    print(f"  当前页面: {page.url[:80]}")

    # 输入搜索词 - 尝试多种选择器
    search_input = None
    for sel in [
        'input[id="search-option"]',
        'input[aria-label*="search term"]',
        'input[aria-label*="Search"]',
        'input[placeholder*="search"]',
        'input[placeholder*="Search"]',
        'input[type="search"]',
        'mat-form-field input',
        '#search-field',
    ]:
        search_input = page.query_selector(sel)
        if search_input:
            print(f"  找到搜索框: {sel}")
            break

    if not search_input:
        print("  未找到搜索框，请确认已打开 WoS 搜索页面")
        print(f"  当前 URL: {page.url}")
        # 保存页面截图帮助调试
        page.screenshot(path="debug_wos.png")
        print("  已截图 debug_wos.png")
        return []

    search_input.fill(query)
    human_delay(0.5, 1)
    search_input.press("Enter")
    page.wait_for_load_state("networkidle", timeout=30000)
    human_delay(3, 5)

    results = []
    entries = page.query_selector_all('app-records-list .summary-record, .search-results .record')

    for entry in entries[:limit]:
        try:
            title_el = entry.query_selector('a[data-ta="summary-record-title-link"], .title a, h3 a')
            title = title_el.inner_text().strip() if title_el else ""
            link = title_el.get_attribute("href") if title_el else ""

            authors_el = entry.query_selector('.authors, [data-ta="summary-record-author"]')
            raw_authors = authors_el.inner_text().strip() if authors_el else ""
            authors = [a.strip() for a in raw_authors.split(",") if a.strip()]

            year_el = entry.query_selector('.date, .pub-year, [data-ta="summary-record-date"]')
            year_text = year_el.inner_text().strip() if year_el else ""
            m = re.search(r'(\d{4})', year_text)
            year = int(m.group(1)) if m else None

            venue_el = entry.query_selector('.journal, .source-title, [data-ta="summary-record-journal"]')
            venue = venue_el.inner_text().strip() if venue_el else ""

            doi_el = entry.query_selector('a[href*="doi.org"]')
            doi = _extract_doi(doi_el.get_attribute("href")) if doi_el else ""

            results.append({
                "title": title, "authors": authors, "year": year,
                "abstract": "", "doi": doi, "venue": venue,
                "citation_count": 0, "source": "wos",
                "url": link, "pdf_url": "",
            })
        except Exception:
            continue

    print(f"  找到 {len(results)} 篇")
    return results


# ── Scopus 搜索 ──────────────────────────────────────────────────

def search_scopus(page, query: str, limit: int = 20) -> list[dict]:
    """在 Scopus 中搜索"""
    print(f"[Scopus] 搜索: {query}")
    page.goto("https://www.scopus.com/search/form.uri?display=basic", wait_until="domcontentloaded", timeout=30000)
    human_delay(3, 6)

    search_input = page.query_selector('#searchterm1, input[name="searchterm1"]')
    if not search_input:
        print("  未找到搜索框，请确认已打开 Scopus 并登录")
        return []
    search_input.fill(query)
    human_delay(0.5, 1)
    search_input.press("Enter")
    human_delay(5, 8)

    results = []
    entries = page.query_selector_all('#srchResultsList .searchArea, .search-result')

    for entry in entries[:limit]:
        try:
            title_el = entry.query_selector('a[data-type="title"], .ddmDocTitle a, h2 a')
            title = title_el.inner_text().strip() if title_el else ""
            link = title_el.get_attribute("href") if title_el else ""

            authors_el = entry.query_selector('.authName, .ddmAuthors')
            raw_authors = authors_el.inner_text().strip() if authors_el else ""
            authors = [a.strip() for a in raw_authors.split(",") if a.strip()]

            year_el = entry.query_selector('.ddmPubYear, .date')
            year_text = year_el.inner_text().strip() if year_el else ""
            m = re.search(r'(\d{4})', year_text)
            year = int(m.group(1)) if m else None

            venue_el = entry.query_selector('.ddmSourceTitle, .source-title')
            venue = venue_el.inner_text().strip() if venue_el else ""

            doi_el = entry.query_selector('a[href*="doi.org"]')
            doi = _extract_doi(doi_el.get_attribute("href")) if doi_el else ""

            results.append({
                "title": title, "authors": authors, "year": year,
                "abstract": "", "doi": doi, "venue": venue,
                "citation_count": 0, "source": "scopus",
                "url": link, "pdf_url": "",
            })
        except Exception:
            continue

    print(f"  找到 {len(results)} 篇")
    return results


# ── 百度学术 ─────────────────────────────────────────────────────

def search_baidu_xueshu(page, query: str, limit: int = 20) -> list[dict]:
    print(f"[百度学术] 搜索: {query}")
    page.goto(f"https://xueshu.baidu.com/s?wd={query}", wait_until="domcontentloaded", timeout=30000)
    human_delay(3, 6)

    if "安全验证" in page.title():
        print("  百度安全验证，请在浏览器中手动完成...")
        input("  完成后按 Enter...")

    results = []
    entries = page.query_selector_all(".sc_default_result .sc_content, .result .sc_content")

    for entry in entries[:limit]:
        try:
            title_el = entry.query_selector("h3 a")
            title = title_el.inner_text().strip() if title_el else ""
            link = title_el.get_attribute("href") if title_el else ""

            meta_el = entry.query_selector(".sc_info, .sc_abstract")
            meta_text = meta_el.inner_text().strip() if meta_el else ""
            m = re.search(r'(\d{4})', meta_text)
            year = int(m.group(1)) if m else None

            doi = _extract_doi(link) if link else ""

            results.append({
                "title": title, "authors": [], "year": year,
                "abstract": "", "doi": doi, "venue": "",
                "citation_count": 0, "source": "baidu_xueshu",
                "url": link, "pdf_url": "",
            })
        except Exception:
            continue

    print(f"  找到 {len(results)} 篇")
    return results


# ── 知网 ─────────────────────────────────────────────────────────

def search_cnki(page, query: str, limit: int = 20) -> list[dict]:
    print(f"[知网] 搜索: {query}")
    page.goto("https://www.cnki.net/", wait_until="domcontentloaded", timeout=30000)
    human_delay(2, 4)

    search_input = page.query_selector('#txt_SearchText, input[name="keyword"]')
    if search_input:
        search_input.fill(query)
        human_delay(0.5, 1)
        search_input.press("Enter")
        human_delay(4, 7)

    if "安全" in page.title() or "验证" in page.title():
        print("  安全验证，请手动完成...")
        input("  完成后按 Enter...")

    results = []
    entries = page.query_selector_all(".result-table-list tbody tr")

    for entry in entries[:limit]:
        try:
            title_el = entry.query_selector("td.name a")
            title = title_el.inner_text().strip() if title_el else ""
            link = title_el.get_attribute("href") if title_el else ""

            author_el = entry.query_selector("td.author")
            raw = author_el.inner_text().strip() if author_el else ""
            authors = [a.strip() for a in raw.split(";") if a.strip()]

            source_el = entry.query_selector("td.source a")
            venue = source_el.inner_text().strip() if source_el else ""

            date_el = entry.query_selector("td.date")
            date_text = date_el.inner_text().strip() if date_el else ""
            m = re.search(r'(\d{4})', date_text)
            year = int(m.group(1)) if m else None

            results.append({
                "title": title, "authors": authors, "year": year,
                "abstract": "", "doi": "", "venue": venue,
                "citation_count": 0, "source": "cnki",
                "url": link, "pdf_url": "",
            })
        except Exception:
            continue

    print(f"  找到 {len(results)} 篇")
    return results


# ── PDF 下载 ──────────────────────────────────────────────────────

def download_papers(papers: list[dict], output_dir: str, page):
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    downloaded, failed = 0, 0

    for i, paper in enumerate(papers):
        title = paper.get("title", "unknown")
        doi = paper.get("doi", "")
        pdf_url = paper.get("pdf_url", "")
        url = paper.get("url", "")

        safe_name = safe_filename(title)
        pdf_path = output_path / f"{safe_name}.pdf"

        if pdf_path.exists():
            print(f"  [{i+1}/{len(papers)}] 已存在: {safe_name[:50]}")
            downloaded += 1
            continue

        target = pdf_url or (f"https://doi.org/{doi}" if doi else url)
        if not target:
            print(f"  [{i+1}/{len(papers)}] 跳过（无链接）: {title[:50]}")
            failed += 1
            continue

        print(f"  [{i+1}/{len(papers)}] 下载: {title[:60]}...")
        try:
            page.goto(target, wait_until="domcontentloaded", timeout=30000)
            human_delay(3, 6)

            success = _try_download(page, pdf_path)
            if success:
                downloaded += 1
                print(f"    OK: {pdf_path.name}")
            else:
                failed += 1
                print(f"    未找到下载链接")
        except Exception as e:
            failed += 1
            print(f"    错误: {e}")

        human_delay(10, 25)
        if (i + 1) % 5 == 0:
            print(f"  --- 已处理 {i+1} 篇，休息 60-120 秒 ---")
            human_delay(60, 120)

    print(f"\n完成: 下载 {downloaded} 篇, 失败 {failed} 篇")
    return downloaded


def _try_download(page, pdf_path: Path) -> bool:
    # PDF embed
    pdf_embed = page.query_selector('iframe[src*=".pdf"], embed[src*=".pdf"]')
    if pdf_embed:
        src = pdf_embed.get_attribute("href") or pdf_embed.get_attribute("src")
        if src and _download_url(page, src, pdf_path):
            return True

    # 下载按钮
    for sel in ['a[href*=".pdf"]', 'a:has-text("Download PDF")', 'a:has-text("PDF")',
                'a:has-text("下载PDF")', 'a:has-text("View PDF")', 'a[title*="PDF"]']:
        try:
            el = page.query_selector(sel)
            if not el:
                continue
            href = el.get_attribute("href")
            if href and ".pdf" in href.lower() and _download_url(page, href, pdf_path):
                return True
            try:
                with page.expect_download(timeout=15000) as dl_info:
                    el.click()
                dl_info.value.save_as(str(pdf_path))
                return True
            except Exception:
                continue
        except Exception:
            continue

    if ".pdf" in page.url.lower():
        return _download_url(page, page.url, pdf_path)
    return False


def _download_url(page, url: str, pdf_path: Path) -> bool:
    try:
        resp = page.request.get(url, timeout=30000)
        if resp.ok and len(resp.body()) > 10000:
            pdf_path.write_bytes(resp.body())
            return True
    except Exception:
        pass
    return False


# ── DOI 工具 ──────────────────────────────────────────────────────

def _extract_doi(url: str) -> str:
    m = re.search(r'(10\.\d{4,}/[^\s&?#]+)', url)
    return m.group(1) if m else ""


# ── 结果管理 ──────────────────────────────────────────────────────

def save_results(papers, output_file):
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(papers, f, ensure_ascii=False, indent=2)
    print(f"保存 {len(papers)} 篇 → {output_file}")


def load_results(input_file):
    with open(input_file, "r", encoding="utf-8") as f:
        return json.load(f)


def print_summary(papers):
    print(f"\n{'='*80}")
    print(f" 共 {len(papers)} 篇论文")
    print(f"{'='*80}")
    for i, p in enumerate(papers):
        authors = ", ".join(p.get("authors", [])[:3])
        if len(p.get("authors", [])) > 3:
            authors += " et al."
        print(f"\n[{i+1}] {p.get('title', 'N/A')}")
        print(f"    {authors} ({p.get('year', 'N/A')}) | {p.get('venue', 'N/A')}")
        print(f"    DOI: {p.get('doi', 'N/A')} | 引用: {p.get('citation_count', 0)}")
        if p.get("abstract"):
            print(f"    摘要: {p['abstract'][:120]}...")


# ── 主程序 ────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="连接已有浏览器，自动搜索+下载论文")
    sub = parser.add_subparsers(dest="cmd")

    sp = sub.add_parser("search", help="搜索论文")
    sp.add_argument("query")
    sp.add_argument("--limit", type=int, default=20)
    sp.add_argument("--source", choices=["scholar", "wos", "scopus", "baidu", "cnki"], default="scholar")
    sp.add_argument("--output", "-o", default="results.json")
    sp.add_argument("--download", "-d", action="store_true")
    sp.add_argument("--pdf-dir", default="./pdfs")

    dp = sub.add_parser("download", help="从 JSON 下载")
    dp.add_argument("input")
    dp.add_argument("--output", "-o", default="./pdfs")

    args = parser.parse_args()

    if args.cmd == "search":
        pw, browser, ctx, page = connect_browser()

        source_fn = {
            "scholar": search_google_scholar,
            "wos": search_wos,
            "scopus": search_scopus,
            "baidu": search_baidu_xueshu,
            "cnki": search_cnki,
        }
        fn = source_fn.get(args.source)
        papers = fn(page, args.query, args.limit) if fn else []

        # 去重
        seen, unique = set(), []
        for p in papers:
            key = p.get("title", "").lower().strip()
            if key and key not in seen:
                seen.add(key)
                unique.append(p)
        papers = unique[:args.limit]

        save_results(papers, args.output)
        print_summary(papers)

        if args.download and papers:
            download_papers(papers, args.pdf_dir, page)

        # 不关闭 browser（它是用户自己的浏览器）
        pw.stop()

    elif args.cmd == "download":
        papers = load_results(args.input)
        print(f"加载 {len(papers)} 篇")
        pw, browser, ctx, page = connect_browser()
        download_papers(papers, args.output, page)
        pw.stop()

    else:
        parser.print_help()


if __name__ == "__main__":
    main()

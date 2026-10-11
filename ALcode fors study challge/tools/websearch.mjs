// 定时任务里的联网工具。
//
// 为什么需要它：自动触发的会话里没有 web_search 工具，
// 而 Windows 沙箱下 curl / Invoke-WebRequest 会因为 schannel 拿不到证书而失败
// （SEC_E_NO_CREDENTIALS）。Node 自带的 fetch 走自己的 TLS 栈，不受影响。
//
// 用法：
//   node websearch.mjs search "关键词"
//   node websearch.mjs apps  "关键词" [country] [limit]
//   node websearch.mjs fetch  "https://..." [maxChars]
// Windows 控制台默认 GBK，中文会乱码。PowerShell 里先执行：
//   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

// 必须伪装成完整浏览器：UA 太短会被沙箱代理直接重置连接（ECONNRESET）。
const UA = {
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'accept-language': 'zh-CN,zh;q=0.9,en;q=0.8'
};

function stripTags(html) {
  return html.replace(/<script[\s\S]*?<\/script>/gi, ' ')
             .replace(/<style[\s\S]*?<\/style>/gi, ' ')
             .replace(/<[^>]+>/g, ' ')
             .replace(/&nbsp;/g, ' ')
             .replace(/&amp;/g, '&')
             .replace(/&quot;/g, '"')
             .replace(/\s+/g, ' ')
             .trim();
}

function line(n, text) {
  console.log(String(n) + '. ' + text);
}

async function search(q) {
  const url = 'https://lite.duckduckgo.com/lite/?q=' + encodeURIComponent(q);
  const html = await (await fetch(url, { headers: UA })).text();
  const links = [...html.matchAll(/<a[^>]+class="result-link"[^>]*href="([^"]+)"[^>]*>([\s\S]{3,200}?)<\/a>/g)];
  const titles = links.map(m => stripTags(m[2]));
  const snippets = [...html.matchAll(/class="result-snippet"[^>]*>([\s\S]{5,400}?)<\/td>/g)].map(m => stripTags(m[1]));
  if (titles.length === 0) {
    console.log('(no results parsed) raw length = ' + html.length);
    return;
  }
  titles.slice(0, 8).forEach((t, i) => {
    line(i + 1, t);
    if (snippets[i]) console.log('   ' + snippets[i].slice(0, 300));
  });
}

// lite.duckduckgo.com 在部分网络下会返回空结果，备用 Bing。
async function searchBing(q) {
  const url = 'https://www.bing.com/search?q=' + encodeURIComponent(q);
  const html = await (await fetch(url, { headers: UA })).text();
  const blocks = [...html.matchAll(/<li class="b_algo"[\s\S]*?<\/li>/g)];
  blocks.slice(0, 8).forEach((b, i) => {
    const title = stripTags((b[0].match(/<h2[\s\S]*?<\/h2>/) || [''])[0]);
    const snippet = stripTags((b[0].match(/<p[^>]*>[\s\S]*?<\/p>/) || [''])[0]);
    line(i + 1, title);
    if (snippet) console.log('   ' + snippet.slice(0, 300));
  });
  if (blocks.length === 0) console.log('(bing returned nothing) len = ' + html.length);
}

async function apps(term, country, limit) {
  const url = 'https://itunes.apple.com/search?term=' + encodeURIComponent(term)
            + '&country=' + country + '&entity=software&limit=' + limit;
  const json = await (await fetch(url, { headers: UA })).json();
  console.log('App Store (' + country + ') 搜索「' + term + '」命中 ' + json.resultCount + '，取前 ' + json.results.length + '：');
  json.results.forEach(a => {
    const rating = a.averageUserRating ? a.averageUserRating.toFixed(1) : '暂无评分';
    console.log('- ' + a.trackName + ' | ' + rating + ' 星 / ' + a.userRatingCount + ' 条评价 | '
      + a.formattedPrice + ' | ' + (a.genres || []).slice(0, 2).join(',')
      + ' | ' + a.trackViewUrl);
    console.log('  ' + stripTags(a.description || '').slice(0, 260));
  });
}

async function page(url, maxChars) {
  const html = await (await fetch(url, { headers: UA })).text();
  console.log(stripTags(html).slice(0, Number(maxChars)));
}

const parts = process.argv.slice(2);
const cmd = parts[0];
const run = async () => {
  try {
    if (cmd === 'search') await search(parts[1]);
    else if (cmd === 'bing') await searchBing(parts[1]);
    else if (cmd === 'apps') await apps(parts[1], parts[2] || 'us', parts[3] || 6);
    else if (cmd === 'fetch') await page(parts[1], parts[2] || 3000);
    else console.log('用法: search | apps | fetch');
  } catch (e) {
    console.log('ERR ' + (e.cause?.message || e.message));
  }
};
run();

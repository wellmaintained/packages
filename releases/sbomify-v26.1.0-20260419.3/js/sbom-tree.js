/**
 * SBOM Component Tree Viewer
 *
 * Reads a CycloneDX JSON file and renders an interactive, collapsible
 * dependency tree. Designed for Hugo static sites — no build step needed.
 *
 * Usage: <div id="sbom-tree" data-sbom-url="/path/to/sbom.cdx.json"></div>
 *        Then call: SBOMTree.init('sbom-tree')
 */
const SBOMTree = (() => {
  const DEFAULT_EXPAND_DEPTH = 3;
  const SEARCH_DEBOUNCE_MS = 150;

  let allNodes = [];
  let searchTimer = null;

  function init(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const url = container.dataset.sbomUrl;
    if (!url) {
      container.innerHTML = '<p><em>No SBOM URL configured.</em></p>';
      return;
    }

    container.innerHTML = '<p>Loading SBOM…</p>';

    fetch(url)
      .then(r => {
        if (!r.ok) throw new Error(`Failed to load SBOM: ${r.status}`);
        return r.json();
      })
      .then(sbom => render(container, sbom))
      .catch(err => {
        container.innerHTML = `<p><em>Could not load SBOM: ${err.message}</em></p>`;
      });
  }

  function render(container, sbom) {
    const components = sbom.components || [];
    const deps = sbom.dependencies || [];

    const byRef = {};
    components.forEach(c => {
      if (c['bom-ref']) byRef[c['bom-ref']] = c;
    });

    const children = {};
    const hasParent = new Set();
    deps.forEach(d => {
      const ref = d.ref;
      const kids = d.dependsOn || [];
      children[ref] = kids;
      kids.forEach(k => hasParent.add(k));
    });

    const depRefs = deps.map(d => d.ref);
    const roots = depRefs.filter(r => !hasParent.has(r));

    if (roots.length === 0 && components.length > 0) {
      roots.push(...components.map(c => c['bom-ref']).filter(Boolean));
    }

    const stats = document.createElement('div');
    stats.className = 'sbom-stats';
    stats.innerHTML = `<strong>${components.length}</strong> components`;

    const controls = document.createElement('div');
    controls.className = 'sbom-controls';
    controls.innerHTML = `
      <button onclick="SBOMTree.setAll(true)">Expand all</button>
      <button onclick="SBOMTree.setAll(false)">Collapse all</button>
      <input type="text" placeholder="Search components…"
             oninput="SBOMTree.debouncedSearch(this.value)" class="sbom-search">
    `;

    const tree = document.createElement('div');
    tree.className = 'sbom-tree-root';
    allNodes = [];

    const visited = new Set();
    roots.forEach(ref => {
      const node = buildNode(ref, byRef, children, 0, visited);
      if (node) tree.appendChild(node);
    });

    container.innerHTML = '';
    container.appendChild(stats);
    container.appendChild(controls);
    container.appendChild(tree);
  }

  function buildNode(ref, byRef, children, depth, visited) {
    if (visited.has(ref)) return null;
    visited.add(ref);

    const comp = byRef[ref];
    const kids = (children[ref] || []).filter(k => !visited.has(k));
    const hasKids = kids.length > 0;
    const expanded = depth < DEFAULT_EXPAND_DEPTH;

    const node = document.createElement('div');
    node.className = 'sbom-node';
    node.dataset.depth = depth;

    const row = document.createElement('div');
    row.className = 'sbom-row';
    row.style.paddingLeft = `${depth * 20}px`;

    const toggle = document.createElement('span');
    toggle.className = 'sbom-toggle';
    if (hasKids) {
      toggle.textContent = expanded ? '▼' : '▶';
      toggle.style.cursor = 'pointer';
      toggle.onclick = () => toggleNode(node, toggle);
    } else {
      toggle.textContent = '·';
      toggle.classList.add('sbom-dimmed');
    }

    const name = document.createElement('span');
    name.className = 'sbom-name';
    name.textContent = comp ? (comp.name || ref) : ref;

    const version = document.createElement('span');
    version.className = 'sbom-version';
    version.textContent = comp && comp.version ? comp.version : '';

    const license = document.createElement('span');
    license.className = 'sbom-license';
    if (comp && comp.licenses && comp.licenses.length > 0) {
      const lic = comp.licenses[0];
      license.textContent = lic.license
        ? (lic.license.id || lic.license.name || '')
        : (lic.expression || '');
    }

    row.appendChild(toggle);
    row.appendChild(name);
    row.appendChild(version);
    row.appendChild(license);

    if (hasKids) {
      const count = document.createElement('span');
      count.className = 'sbom-childcount';
      count.textContent = `+ ${kids.length} deps`;
      count.style.display = expanded ? 'none' : 'inline';
      row.appendChild(count);
    }

    node.appendChild(row);

    if (hasKids) {
      const childContainer = document.createElement('div');
      childContainer.className = 'sbom-children';
      childContainer.style.display = expanded ? 'block' : 'none';

      const childVisited = new Set(visited);
      kids.forEach(k => {
        const childNode = buildNode(k, byRef, children, depth + 1, childVisited);
        if (childNode) childContainer.appendChild(childNode);
      });

      node.appendChild(childContainer);
    }

    allNodes.push(node);
    return node;
  }

  function toggleNode(node, toggle) {
    const children = node.querySelector('.sbom-children');
    const count = node.querySelector('.sbom-childcount');
    if (!children) return;

    const showing = children.style.display !== 'none';
    children.style.display = showing ? 'none' : 'block';
    toggle.textContent = showing ? '▶' : '▼';
    if (count) count.style.display = showing ? 'inline' : 'none';
  }

  function setAll(expanded) {
    allNodes.forEach(node => {
      const children = node.querySelector('.sbom-children');
      const toggle = node.querySelector('.sbom-toggle');
      const count = node.querySelector('.sbom-childcount');
      if (children) {
        children.style.display = expanded ? 'block' : 'none';
        if (toggle) toggle.textContent = expanded ? '▼' : '▶';
        if (count) count.style.display = expanded ? 'none' : 'inline';
      }
    });
  }

  function debouncedSearch(query) {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => search(query), SEARCH_DEBOUNCE_MS);
  }

  function search(query) {
    const q = query.toLowerCase().trim();
    if (q === '') {
      allNodes.forEach(node => {
        node.style.display = '';
        const children = node.querySelector(':scope > .sbom-children');
        const toggle = node.querySelector(':scope > .sbom-row > .sbom-toggle');
        const count = node.querySelector(':scope > .sbom-row > .sbom-childcount');
        if (children) {
          const depth = parseInt(node.dataset.depth || '0');
          const expanded = depth < DEFAULT_EXPAND_DEPTH;
          children.style.display = expanded ? 'block' : 'none';
          if (toggle) toggle.textContent = expanded ? '▼' : '▶';
          if (count) count.style.display = expanded ? 'none' : 'inline';
        }
      });
      return;
    }
    const reversed = [...allNodes].reverse();
    reversed.forEach(node => {
      const name = node.querySelector(':scope > .sbom-row > .sbom-name');
      if (!name) return;
      const selfMatch = name.textContent.toLowerCase().includes(q);
      const childContainer = node.querySelector(':scope > .sbom-children');
      let childMatch = false;
      if (childContainer) {
        const childNodes = childContainer.querySelectorAll(':scope > .sbom-node');
        childMatch = Array.from(childNodes).some(c => c.style.display !== 'none');
      }
      const visible = selfMatch || childMatch;
      node.style.display = visible ? '' : 'none';
      if (childContainer && childMatch) {
        childContainer.style.display = 'block';
        const toggle = node.querySelector(':scope > .sbom-row > .sbom-toggle');
        const count = node.querySelector(':scope > .sbom-row > .sbom-childcount');
        if (toggle) toggle.textContent = '▼';
        if (count) count.style.display = 'none';
      }
    });
  }

  return { init, setAll, debouncedSearch, search };
})();

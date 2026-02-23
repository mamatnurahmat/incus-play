# Analisa dan Solusi CNI IP Leak (Kelelahan IPAM) pada Node Kubernetes

## Latar Belakang Masalah (Issue)
Terjadi kegagalan pada saat me-deploy *Pod* `cattle-fleet-system` dengan pesan peringatan:
```
failed to setup network for sandbox ... plugin type="calico" failed (add): failed to allocate for range 0: no IP addresses available in range set: 10.42.1.1-10.42.1.254
```
Peringatan ini menandakan terjadinya **IPAM (IP Address Management) Exhaustion**, yang berarti sistem kehabisan alokasi alamat IP untuk *Pod* pada sebuah *node* spesifik (dalam kasus ini: *node* `rke2-agent01`). Ruang alokasi subnet `/24` (berkisar dari `10.42.1.1` sampai `10.42.1.254`) yang direkam oleh komponen CNI telah terpakai semua, meskipun sebenarnya *Pod* yang berjalan hanya ada beberapa.

## Analisa Akar Masalah (Root Cause)
Secara arsitektur, setiap *node* *worker* di dalam klaster Kubernetes mendapatkan jatah *subnet* IP lokal, contohnya `10.42.1.0/24`. Saat *Pod* dibuat, *plugin networking host-local* akan membuat sebuah "file rekaman alokasi" menggunakan nama IP tersebut di dalam direktori sistem OS. Umumnya letak direktori ini ada di `/var/lib/cni/networks/<nama-network>/`.

Ketika *Pod* tersebut dihapus, agen `kubelet` seharusnya menginformasikan ke *plugin* CNI untuk melepaskan (*release*) IP dan menghapus file rekaman alokasi tersebut.

Masalah **kebocoran IP (*IP Leaking*)** ini muncul karena rekaman file-file tersebut menumpuk tanpa pernah dibersihkan. Insiden penumpukan ini biasanya dipicu oleh hal-hal berikut:
1. **Force Deletion Pod ("Pemaksaan Hapus")**: Memaksa penghapusan `Pod` dengan flag `--force --grace-period=0` dapat menyebabkan API Server menghapus entitas `Pod` secara instan dari etalase abstraksi Kubernetes sebelum `kubelet` pada *node* tersebut sempat memberikan instruksi perapian koneksi dan IP CNI.
2. **Koneksi Terputus/Node Mati Mendadak (Hard Crash)**: Apabila *node* VM dimatikan mendadak (*Hard Reboot/Power Off*), atau layanan *container runtime* (`containerd`) serta `kubelet`-nya tiba-tiba mengalami *crash* saat sedang ada proses pendirian/penghapusan *Pod*, proses *teardown* IP akan terlewatkan.
3. **OOM / CPU Throttling Ekstrem pada Node**: *Node* yang kehabisan resosur *memory/cpu* akan memutus koneksi komunikasi lokal dalam *node* untuk sementara, menyebabkan instruksi pembersihan IP gagal dijalankan atau *timeout*.

Ini mengakibatkan sistem merasa "IP masih ada yang memakai" *(tercatat ada 255 file statis)* sedangkan kenyataannya di dalam API Kubernetes *cluster* sudah tidak ada pod yang memakai IP tersebut.

---

## Solusi (Remediasi) yang Direalisasikan
Tindakan logis utamanya adalah **menghapus secara manual dan selektif** file alokasi IP palsu/stale tersebut, yang bisa dilakukan dengan eksekusi script:
1. **Melakukan Sinkronisasi IP Riil**: Kita mengekstrak semua IP *Pod* yang benar-benar tercatat secara sah di API Kubernetes dan berjalan di atas node `rke2-agent01`.
2. **Pembersihan Record CNI (Garbage Collection Manual)**: Lewat *shell* Incus, script berjalan menelusuri folder `/var/lib/cni/networks/k8s-pod-network/` lalu MENGHAPUS semua *file* IP yang TIDAK ADA dalam daftar IP Riil tersebut.
3. **Validasi & Trigger Ulang Pod**: Karena *IP allocation pool* sudah sehat dan ruang kosong tersedia (dari batas kuota 254 keping), *Pod* baru yang tadinya terjebak pada `ContainerCreating` dan ter-blokir akan langsung mendapatkan inisialisasi *Networking IP* baru dengan sukses.

*(Script operasional sudah saya simpan di `/home/mamat/.gemini/antigravity/scratch/cleanup-cni.sh`)*

---

## Antisipasi dan Pencegahan Masa Depan

1. **Biasakan *Graceful Termination***
   Jangan langsung mengeksekusi *force-delete* saat melihat status *Pod* menjadi `Terminating` atau `ImagePullBackOff`. Biarkan sistem CNI membersihkan perutingannya sendiri. Apabila Pod tidak kunjung hilang, investigasi dan **restart agen node-nya (`systemctl restart rke2-agent`)** alih-alih merusak API server dengan *force-delete*.
   
2. **Prosedur *Reboot Node* secara *Graceful***
   Jika Anda berniat mematikan / merestart `rke2-agent01` melalui Incus, pastikan di dalam klaster untuk melakukan Drain `kubectl drain rke2-agent01 --ignore-daemonsets`. Ini memberi jeda waktu CNI mencabuti alokasi IP secara natural karena memindahkan proses *Pod*-nya ke node lain yang kosong.
   
3. **Pengawasan Ketat Ruang Kapasitas Subnet (Monitoring)**
   Apabila skema rke2/k3s Anda digunakan untuk tipe *Workload* berupa *CronJob* atau *Pipeline CI/CD Runner* (yang siklus membuat Pod lalu mati secara amat cepat dan sering), pastikan CNI *garbage collector loop* bisa mengimbangi laju pembuatan IP-nya. Jika dirasa tidak kuat (*churn rate* tinggi), sangat disarankan **Mengekspansi Blok Pod CIDR**, misalkan node bisa dialokasikan memakai *subnet* `/23` (sehingga ada sisa 510 alamat IP yang tersedia).

4. **Eksekusi Script Detoks IP**
   Sebagai penanggulangan terbelakang, jadikan script `cleanup-cni.sh` sebagai sarana S.O.P administrasi. Bila tiba-tiba node RKE2 kembali dihidupkan (pasca pemadaman *host machine/server* mati lampu), langsung jalankan script tersebut untuk menyingkirkan *IP Leak* yang tersangkut.
